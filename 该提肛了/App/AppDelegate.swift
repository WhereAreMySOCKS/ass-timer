import SwiftUI
import AppKit

/// Main application delegate.
/// Manages the floating pet window lifecycle, onboarding, and all secondary windows.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: NSWindow?
    private var bubbleWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var leaderboardWindow: NSWindow?
    private var groupInfoWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var chatWindow: NSWindow?
    private var intervalWindow: NSWindow?

    let appState = AppState()
    private var windowManager = FloatingPetWindowManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // Register for window action notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showLeaderboardNotif),
            name: .showLeaderboard,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showGroupInfoNotif),
            name: .showGroupInfo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showIntervalModifierNotif),
            name: .showIntervalModifier,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettingsNotif),
            name: .showSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showChatNotif),
            name: .showChat,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(petWindowDidMove),
            name: .petWindowDidMove,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localDataClearedNotif),
            name: .localDataCleared,
            object: nil
        )

        // Check if onboarding is complete
        if appState.config.onboardingComplete {
            showPetWindow()
            appState.onAppLaunch()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.onAppTerminate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Windows

    func showOnboarding() {
        NSApp.setActivationPolicy(.regular)

        let onboardingView = OnboardingView(appState: appState) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.showPetWindow()
            self?.appState.onAppLaunch()
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 365),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "该提肛了 - 设置"
        window.minSize = NSSize(width: 640, height: 340)
        window.maxSize = NSSize(width: 740, height: 390)
        window.center()
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Adjust window height based on content
        DispatchQueue.main.async {
            let fittingSize = hostingController.view.fittingSize
            let newWidth = max(640, min(740, fittingSize.width))
            let newHeight = max(340, min(390, fittingSize.height))
            window.setContentSize(NSSize(width: newWidth, height: newHeight))
            window.center()
        }
        self.onboardingWindow = window
    }

    func showPetWindow() {
        // Create the floating pet window
        let window = windowManager.createWindow(appState: appState)
        window.makeKeyAndOrderFront(nil)
        self.petWindow = window

        // Wire pet window into activity engine for walking movement
        appState.activityEngine.petWindow = window

        // Create the bubble overlay window
        showBubbleWindow()

        // Hide from Dock when only pet is showing
        NSApp.setActivationPolicy(.accessory)
    }

    func showBubbleWindow() {
        let bubbleView = BubbleOverlayView(appState: appState)

        let hostingView = NSHostingView(rootView: bubbleView)

        let size = Constants.bubbleOverlaySize
        let origin = bubbleWindowOrigin()

        let window = PassthroughWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.setHostedView(hostingView)

        window.makeKeyAndOrderFront(nil)
        self.bubbleWindow = window
    }

    // MARK: - Leaderboard

    func showLeaderboard() {
        if let existing = leaderboardWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let leaderboardView = LeaderboardView(appState: appState)

        let hostingView = NSHostingView(rootView: leaderboardView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "排行榜"
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.leaderboardWindow = window
    }

    // MARK: - Group Info

    func showGroupInfo() {
        if let existing = groupInfoWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: GroupInfoView(appState: appState))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "群组信息"
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.groupInfoWindow = window
    }

    // MARK: - Chat

    func showChat() {
        if let existing = chatWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let chatView = ChatView(appState: appState)

        let hostingView = NSHostingView(rootView: chatView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "群聊"
        window.minSize = NSSize(width: 560, height: 380)
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.chatWindow = window
    }

    // MARK: - Settings

    func showSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(appState: appState)

        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.settingsWindow = window
    }

    // MARK: - Interval Modifier

    private func showIntervalModifier() {
        let modifierView = IntervalModifierView(appState: appState) { [weak self] in
            self?.intervalWindow?.close()
            self?.intervalWindow = nil
        }

        let hostingView = NSHostingView(rootView: modifierView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 225, height: 240),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "修改间隔"
        window.center()
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.intervalWindow = window
    }

    // MARK: - Notification Handlers

    @objc private func showLeaderboardNotif() { showLeaderboard() }
    @objc private func showGroupInfoNotif() { showGroupInfo() }
    @objc private func showIntervalModifierNotif() { showIntervalModifier() }
    @objc private func showSettingsNotif() { showSettings() }
    @objc private func showChatNotif() { showChat() }
    @objc private func localDataClearedNotif() { resetWindowsForOnboarding() }

    // MARK: - Sleep / Wake

    @objc private func handleSleep() {
        appState.timerEngine.handleSleep()
        appState.activityEngine.stop()
    }

    @objc private func handleWake() {
        appState.timerEngine.handleWake(intervalSeconds: appState.config.intervalSeconds)
        if appState.currentState == .running {
            appState.activityEngine.start()
        }
    }

    @objc private func petWindowDidMove() {
        repositionBubbleWindow()
    }

    private func resetWindowsForOnboarding() {
        petWindow?.close()
        petWindow = nil
        bubbleWindow?.close()
        bubbleWindow = nil
        leaderboardWindow?.close()
        leaderboardWindow = nil
        groupInfoWindow?.close()
        groupInfoWindow = nil
        settingsWindow?.close()
        settingsWindow = nil
        chatWindow?.close()
        chatWindow = nil
        intervalWindow?.close()
        intervalWindow = nil

        if let existing = onboardingWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
        } else {
            showOnboarding()
        }
    }

    private func repositionBubbleWindow() {
        guard let bubbleWindow else { return }
        bubbleWindow.setFrame(NSRect(origin: bubbleWindowOrigin(), size: Constants.bubbleOverlaySize), display: true)
    }

    private func bubbleWindowOrigin() -> NSPoint {
        let size = Constants.bubbleOverlaySize
        guard let petFrame = self.petWindow?.frame else {
            guard let visibleFrame = NSScreen.main?.visibleFrame else { return .zero }
            return NSPoint(
                x: visibleFrame.maxX - size.width - Constants.petScreenEdgeMargin,
                y: visibleFrame.maxY - size.height - Constants.petScreenEdgeMargin
            )
        }

        let visibleFrame = NSScreen.screens.first(where: { $0.visibleFrame.intersects(petFrame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame

        let petContentCenterX = petFrame.minX + Constants.petContentSize.width / 2
        let spriteTopY = petFrame.minY
            + (Constants.petContentSize.height - Constants.petSpriteSize.height) / 2
            + Constants.petSpriteSize.height

        var origin = NSPoint(
            x: petContentCenterX - size.width / 2,
            y: spriteTopY - Constants.bubbleTailOverlap
        )

        if let visibleFrame {
            let margin = Constants.bubbleScreenEdgeMargin
            origin.x = min(max(origin.x, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
            origin.y = min(max(origin.y, visibleFrame.minY + margin), visibleFrame.maxY - size.height - margin)
        }

        return origin
    }
}
