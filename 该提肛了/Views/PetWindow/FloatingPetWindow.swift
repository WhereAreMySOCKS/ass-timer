import SwiftUI
import AppKit

/// Creates and manages the floating pet window.
/// Uses a borderless NSWindow that floats above all other windows.
@objc(FloatingPetWindowManager)
final class FloatingPetWindowManager: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private weak var appState: AppState?

    func createWindow(appState: AppState) -> NSWindow {
        self.appState = appState

        // Calculate initial position
        let initialOrigin = restorePosition()
        let size = CGSize(width: Constants.petWindowTotalWidth, height: Constants.petWindowDefaultSize.height)

        let window = NSWindow(
            contentRect: NSRect(origin: initialOrigin, size: size),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        // Floating window configuration — .popUpMenu level sits above fullscreen apps
        window.level = .popUpMenu
        window.isOpaque = false
        window.backgroundColor = .clear
        // Transparent borderless window shadows are inconsistent on older
        // macOS versions. PetView draws an alpha-aware shadow around the sprite.
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.delegate = self

        // Content: PetView with interaction overlay
        let contentView = PetWindowContent(appState: appState)
        window.contentView = NSHostingView(rootView: contentView)

        self.window = window
        return window
    }

    private func restorePosition() -> NSPoint {
        let size = CGSize(width: Constants.petWindowTotalWidth, height: Constants.petWindowDefaultSize.height)
        if let saved = PersistenceManager.shared.loadWindowPosition() {
            let savedPoint = NSPoint(x: saved.x, y: saved.y)
            if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(savedPoint) }) {
                return clampedOrigin(savedPoint, size: size, visibleFrame: screen.visibleFrame)
            }
        }
        // Default: bottom-right corner
        guard let screen = NSScreen.main else { return .zero }
        let visibleFrame = screen.visibleFrame
        return NSPoint(
            x: visibleFrame.maxX - size.width - Constants.petScreenEdgeMargin,
            y: visibleFrame.minY + Constants.petScreenEdgeMargin
        )
    }

    private func clampedOrigin(_ origin: NSPoint, size: CGSize, visibleFrame: NSRect) -> NSPoint {
        let margin = Constants.petScreenEdgeMargin
        let minX = visibleFrame.minX + margin
        let maxX = visibleFrame.maxX - size.width - margin
        let minY = visibleFrame.minY + margin
        let maxY = visibleFrame.maxY - size.height - margin
        return NSPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let frame = window.frame
        PersistenceManager.shared.saveWindowPosition(x: frame.origin.x, y: frame.origin.y)
        NotificationCenter.default.post(name: .petWindowDidMove, object: nil, userInfo: ["frame": frame])
    }

    func windowDidResignKey(_ notification: Notification) {
        // Keep floating above everything including fullscreen apps
        window?.level = .popUpMenu
    }
}

// MARK: - Pet Window Content (SwiftUI View)

struct PetWindowContent: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var updateService: UpdateService
    @State private var showMenu = false
    @State private var pendingSingleClick: DispatchWorkItem?
    @State private var isHovering = false

    init(appState: AppState) {
        self.appState = appState
        _updateService = ObservedObject(wrappedValue: appState.updateService)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Pet content area (original size)
            ZStack(alignment: .center) {
                // Transparent background
                Color.clear

                // Pet
                PetView(appState: appState)

                // Invisible interaction handler overlay (clicks only; hover handled by .onHover on outer container)
                PetInteractionHandler(
                    onSingleClick: { handleSingleClick() },
                    onDoubleClick: { handleDoubleClick() },
                    onRightClick: { showMenu = true }
                )
                .frame(width: Constants.petContentSize.width, height: Constants.petContentSize.height)

                // Update badge (top-right corner)
                if updateService.hasUpdate {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Text("!")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: -4, y: 4)
                        }
                        Spacer()
                    }
                    .frame(width: Constants.petContentSize.width, height: Constants.petContentSize.height)
                }

                // Transient error overlay
                if let error = appState.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .offset(y: 100)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(width: Constants.petContentSize.width, height: Constants.petContentSize.height)

            // Action buttons (right side of pet, fades in on hover)
            PetActionButtons(appState: appState, isVisible: $isHovering)
                .frame(width: Constants.petActionButtonAreaWidth)
        }
        .frame(width: Constants.petWindowTotalWidth, height: Constants.petContentSize.height)
        // Use .onHover on the full window area as the primary hover detector.
        // The PetInteractionHandler tracking area only covers the pet sprite area,
        // so moving the mouse from the pet to the action buttons would trigger
        // mouseExited and hide the buttons before the user could click them.
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.lastError)
        .animation(.easeInOut(duration: 0.3), value: updateService.hasUpdate)
        .contextMenu {
            if updateService.hasUpdate {
                Button("发现新版本 v\(updateService.latestVersion ?? "")") {
                    updateService.openDownloadPage()
                }
                Divider()
            }

            Button("群组信息") {
                NotificationCenter.default.post(name: .showGroupInfo, object: nil)
            }
            .disabled(!appState.config.hasGroup)

            Button("排行榜") {
                NotificationCenter.default.post(name: .showLeaderboard, object: nil)
            }
            .disabled(!appState.config.hasGroup)

            Divider()

            Button("修改间隔…") {
                NotificationCenter.default.post(name: .showIntervalModifier, object: nil)
            }

            Button("设置…") {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            }

            Divider()

            Button("退出") {
                appState.onAppTerminate()
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func handleSingleClick() {
        pendingSingleClick?.cancel()
        let task = DispatchWorkItem { [weak appState] in
            appState?.showInteractionSprite("愤怒", duration: 2)
        }
        pendingSingleClick = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
    }

    private func handleDoubleClick() {
        pendingSingleClick?.cancel()
        pendingSingleClick = nil

        if appState.currentState == .reminder {
            appState.completeKegel()
            return
        }

        appState.activityEngine.triggerFlyUp()
    }
}
