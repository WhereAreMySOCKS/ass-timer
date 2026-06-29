import Foundation
import SwiftUI
import Combine

/// Central ObservableObject that owns the entire app state:
/// - State machine transitions
/// - Bubble queue management
/// - Configuration
/// - Coordination of TimerEngine, APIClient, WebSocketClient
@MainActor                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published var currentState: TimerState = .idle
    @Published var bubbles: [BubbleItem] = []
    @Published var config: UserConfig
    @Published var isLeaderboardVisible = false
    @Published var isGroupInfoVisible = false
    @Published var isAnimating = false
    @Published var lastError: String?
    @Published var groupEventAnimationID: UUID?
    @Published var currentSpriteFrame: String?  // Current sprite keyframe (set by PetActivityEngine)
    @Published var interactionSpriteFrame: String?
    private var interactionSpriteResetTask: DispatchWorkItem?
    private var updateCheckTimer: Timer?

    // MARK: - Services

    let timerEngine = TimerEngine()
    let apiClient = APIClient(baseURL: Constants.apiBaseURL)
    let activityEngine = PetActivityEngine()
    let updateService = UpdateService(baseURL: Constants.apiBaseURL)
    var wsClient: WebSocketClient?

    // MARK: - Init

    init() {
        self.config = PersistenceManager.shared.loadConfig()
        self.wsClient = WebSocketClient(appState: self)

        // Wire up the timer engine callback
        timerEngine.onFire = { [weak self] in
            Task { @MainActor in
                self?.onTimerFire()
            }
        }

        // Wire up activity engine
        activityEngine.appState = self
    }

    // MARK: - State Machine

    func transition(to newState: TimerState) {
        guard currentState != newState else { return }
        currentState = newState
    }

    private func onTimerFire() {
        transition(to: .reminder)
        activityEngine.stop()
        addBubble(.reminder)
    }

    // MARK: - Onboarding Completion

    func completeOnboarding() {
        config.onboardingComplete = true
        PersistenceManager.shared.onboardingComplete = true
        PersistenceManager.shared.saveConfig(config)

        // Connect WebSocket
        if let uid = config.userID {
            Task {
                await wsClient?.connect(userID: uid)
            }
        }

        // Start the timer (may fire immediately if overdue)
        timerEngine.start(intervalSeconds: config.intervalSeconds)
        startPetActivityIfTimerIsRunning()
    }

    // MARK: - Kegel Completion

    func completeKegel() {
        guard currentState == .reminder else { return }
        transition(to: .waitConfirm)
        removeBubble(kind: .reminder)

        // Fire-and-forget: log event to ALL joined groups
        let groupIDs = config.joinedGroups.map(\.groupID)
        Task {
            do {
                if !groupIDs.isEmpty {
                    _ = try await apiClient.logEvent(userID: config.userID ?? "", groupIDs: groupIDs)
                } else {
                    _ = try await apiClient.logEvent(userID: config.userID ?? "", groupIDs: nil)
                }
            } catch {
                lastError = "无法连接后端，已记录本地"
                clearError(after: 3)
            }
        }

        // Increment local counter (only once, regardless of number of groups)
        PersistenceManager.shared.incrementEventCount()
        config.localEventCount = PersistenceManager.shared.localEventCount

        // Hold for confirmation, then reset
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.confirmHoldDuration) { [weak self] in
            guard let self else { return }
            self.transition(to: .reset)
            self.timerEngine.reset(intervalSeconds: self.config.intervalSeconds)
            self.transition(to: .running)
            // Resume pet activity
            self.activityEngine.start()
        }
    }

    // MARK: - Bubble Queue

    func addBubble(_ kind: BubbleKind, senderNickname: String? = nil, senderPetEmoji: String? = nil, senderAvatarURL: String? = nil, message: String? = nil) {
        // Prevent duplicate reminder bubbles
        if kind == .reminder && bubbles.contains(where: { $0.kind == .reminder }) {
            return
        }

        let item = BubbleItem(
            kind: kind,
            senderNickname: senderNickname,
            senderPetEmoji: senderPetEmoji,
            senderAvatarURL: senderAvatarURL,
            message: message,
            timestamp: Date()
        )
        bubbles.append(item)

        // Sort: reminder first, then FIFO by timestamp
        bubbles.sort { a, b in
            if a.kind == .reminder { return true }
            if b.kind == .reminder { return false }
            return a.timestamp < b.timestamp
        }

        // Auto-dismiss group events and chat bubbles after 5 seconds
        if kind == .groupEvent || kind == .chatMessage {
            // Trigger pet wiggle animation
            groupEventAnimationID = UUID()

            let itemId = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.groupBubbleDuration) { [weak self] in
                self?.removeBubble(id: itemId)
            }
        }
    }

    func removeBubble(kind: BubbleKind) {
        withAnimation(.easeOut(duration: 0.3)) {
            bubbles.removeAll { $0.kind == kind }
        }
    }

    func removeBubble(id: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            bubbles.removeAll { $0.id == id }
        }
    }

    func removeAllBubbles() {
        withAnimation(.easeOut(duration: 0.3)) {
            bubbles.removeAll()
        }
    }

    // MARK: - Interval Modification

    func modifyInterval(_ newSeconds: Int) {
        let normalizedSeconds = Constants.normalizedIntervalSeconds(newSeconds)
        config.intervalSeconds = normalizedSeconds
        PersistenceManager.shared.saveConfig(config)
        timerEngine.reset(intervalSeconds: normalizedSeconds)
        startPetActivityIfTimerIsRunning()
    }

    // MARK: - Group Management

    func addGroup(groupID: String, groupName: String, inviteCode: String) {
        // Don't add duplicates
        guard !config.joinedGroups.contains(where: { $0.groupID == groupID }) else { return }
        config.joinedGroups.append(
            JoinedGroup(groupID: groupID, groupName: groupName, inviteCode: inviteCode)
        )
        PersistenceManager.shared.saveConfig(config)
    }

    func updateGroup(groupID: String?, groupName: String?, inviteCode: String?) {
        // Legacy support: add group if provided
        if let gid = groupID {
            addGroup(groupID: gid, groupName: groupName ?? "", inviteCode: inviteCode ?? "")
        }
    }

    func leaveGroup(groupID: String) {
        guard let uid = config.userID else { return }
        Task {
            do {
                try await apiClient.leaveGroup(userID: uid, groupID: groupID)
                config.joinedGroups.removeAll { $0.groupID == groupID }
                PersistenceManager.shared.saveConfig(config)
            } catch {
                lastError = "无法离开群组，请稍后重试"
                clearError(after: 3)
            }
        }
    }

    // MARK: - Chat

    func onChatMessageReceived(groupID: String, message: ChatMessageResponse) {
        // Don't show a bubble for the user's own messages
        if message.user_id != config.userID {
            addBubble(
                .chatMessage,
                senderNickname: message.nickname,
                senderPetEmoji: message.pet_emoji,
                senderAvatarURL: message.avatar_url,
                message: message.content
            )
        }

        // Forward to ChatView for in-window display
        NotificationCenter.default.post(
            name: .chatMessageReceived,
            object: nil,
            userInfo: [
                "groupID": groupID,
                "message": message,
            ]
        )
    }

    func clearError(after seconds: TimeInterval = 3) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.lastError = nil
        }
    }

    func showInteractionSprite(_ spriteName: String, duration: TimeInterval = 2) {
        interactionSpriteResetTask?.cancel()
        interactionSpriteFrame = spriteName

        let task = DispatchWorkItem { [weak self] in
            self?.interactionSpriteFrame = nil
            self?.interactionSpriteResetTask = nil
        }
        interactionSpriteResetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    // MARK: - Lifecycle

    func onAppLaunch() {
        if config.onboardingComplete {
            timerEngine.start(intervalSeconds: config.intervalSeconds)
            startPetActivityIfTimerIsRunning()

            // Connect WebSocket if we have a user
            if let uid = config.userID {
                Task {
                    await wsClient?.connect(userID: uid)
                }
            }

            // Check for app updates
            Task {
                await updateService.checkForUpdate()
            }

            scheduleAutomaticUpdateChecks()
        }
    }

    func onAppTerminate() {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
        timerEngine.stop()
        Task {
            await wsClient?.disconnect()
        }
    }

    func checkForUpdateAfterWake() {
        Task {
            await updateService.checkForUpdate(silently: true)
        }
    }

    private func scheduleAutomaticUpdateChecks() {
        updateCheckTimer?.invalidate()
        let interval = Constants.appUpdateCheckInterval
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task {
                    await self.updateService.checkForUpdate(silently: true)
                }
            }
        }
    }

    // MARK: - Persistence

    func saveConfig() {
        PersistenceManager.shared.saveConfig(config)
    }

    func clearLocalData() async {
        let existingUserID = config.userID
        timerEngine.stop()
        activityEngine.stop()

        if let existingUserID {
            do {
                try await apiClient.deleteUser(userID: existingUserID)
            } catch {
                lastError = "无法清除后端用户，请稍后重试"
                clearError(after: 3)
                return
            }
        }

        PersistenceManager.shared.clearAllLocalData()
        LocalCacheManager.shared.clearAllCaches()

        config = UserConfig()
        currentState = .idle
        bubbles = []
        lastError = nil
        groupEventAnimationID = nil
        currentSpriteFrame = nil
        interactionSpriteFrame = nil
        interactionSpriteResetTask?.cancel()
        interactionSpriteResetTask = nil
        isLeaderboardVisible = false
        isGroupInfoVisible = false
        isAnimating = false

        Task {
            await wsClient?.disconnect()
        }

        NotificationCenter.default.post(name: .localDataCleared, object: nil)
    }

    private func startPetActivityIfTimerIsRunning() {
        // TimerEngine owns the absolute-time schedule; AppState owns the UI state.
        // Keep them in sync before PetActivityEngine checks AppState.currentState.
        guard timerEngine.state == .running else { return }
        transition(to: .running)
        activityEngine.start()
    }
}
