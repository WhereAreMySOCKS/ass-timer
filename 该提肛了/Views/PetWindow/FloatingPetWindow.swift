import SwiftUI
import AppKit

final class FloatingPetNSWindow: NSWindow {
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    private var mouseDownLocation: NSPoint?
    private let dragThreshold: CGFloat = 5

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            mouseDownLocation = event.locationInWindow
            super.sendEvent(event)
        case .leftMouseDragged:
            if let down = mouseDownLocation {
                let dx = event.locationInWindow.x - down.x
                let dy = event.locationInWindow.y - down.y
                if sqrt(dx * dx + dy * dy) > dragThreshold {
                    mouseDownLocation = nil
                    onDragStart?()
                }
            }
            super.sendEvent(event)
        case .leftMouseUp:
            mouseDownLocation = nil
            super.sendEvent(event)
            onDragEnd?()
        default:
            super.sendEvent(event)
        }
    }
}

/// Creates and manages the floating pet window.
/// Uses a borderless NSWindow that floats above all other windows.
@objc(FloatingPetWindowManager)
final class FloatingPetWindowManager: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private weak var appState: AppState?
    private var isAdjustingFrame = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func createWindow(appState: AppState) -> NSWindow {
        self.appState = appState
        NotificationCenter.default.removeObserver(self, name: .revealPetWindow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .dockPetWindowLeft, object: nil)

        // Calculate initial position
        let initialOrigin = restorePosition()
        let size = CGSize(width: Constants.petWindowTotalWidth, height: Constants.petWindowDefaultSize.height)

        let window = FloatingPetNSWindow(
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

        window.onDragStart = { [weak self] in
            self?.windowWillBeginLiveMove()
        }
        window.onDragEnd = { [weak self, weak window] in
            guard let window else { return }
            self?.windowDidEndLiveMove(window)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(revealPetWindow(_:)),
            name: .revealPetWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockPetWindowLeft(_:)),
            name: .dockPetWindowLeft,
            object: nil
        )

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

    private func windowWillBeginLiveMove() {
        guard appState?.isPetDocked == true else { return }
        revealWindow(fullyInsideScreen: false, animated: false)
    }

    private func windowDidEndLiveMove(_ window: NSWindow) {
        guard window === self.window,
              appState?.isObedientMode == true,
              appState?.isLeavingObedientMode == false else { return }
        snapToEdgeIfNeeded(window)
    }

    @objc private func revealPetWindow(_ notification: Notification) {
        revealWindow(fullyInsideScreen: true, animated: true)
    }

    @objc private func dockPetWindowLeft(_ notification: Notification) {
        guard let window else { return }
        dockWindow(window, side: .left, animated: true)
    }

    private func snapToEdgeIfNeeded(_ window: NSWindow) {
        guard !isAdjustingFrame, let visibleFrame = targetScreen(for: window)?.visibleFrame else { return }

        let spriteMinX = window.frame.minX + Constants.petWindowPadding
        let spriteMaxX = spriteMinX + Constants.petSpriteSize.width
        let threshold = Constants.petEdgeSnapThreshold
        let shouldDockLeft = spriteMinX <= visibleFrame.minX + threshold
        let shouldDockRight = spriteMaxX >= visibleFrame.maxX - threshold
        guard shouldDockLeft || shouldDockRight else { return }

        let dockOnLeft: Bool
        if shouldDockLeft && shouldDockRight {
            dockOnLeft = abs(spriteMinX - visibleFrame.minX) <= abs(visibleFrame.maxX - spriteMaxX)
        } else {
            dockOnLeft = shouldDockLeft
        }

        dockWindow(window, side: dockOnLeft ? .left : .right, animated: true)
    }

    private func dockWindow(_ window: NSWindow, side: PetDockSide, animated: Bool) {
        guard !isAdjustingFrame, let visibleFrame = targetScreen(for: window)?.visibleFrame else { return }

        NotificationCenter.default.post(name: .collapsePetMenu, object: nil)
        appState?.setPetDockSide(side)

        let targetX: CGFloat
        switch side {
        case .left:
            targetX = visibleFrame.minX - Constants.petWindowPadding
        case .right:
            targetX = visibleFrame.maxX
                - Constants.petSpriteSize.width
                - Constants.petWindowPadding
        }
        let targetY = min(
            max(window.frame.minY, visibleFrame.minY),
            visibleFrame.maxY - window.frame.height
        )
        let targetFrame = NSRect(
            x: targetX,
            y: targetY,
            width: Constants.petDockedWindowWidth,
            height: window.frame.height
        )

        isAdjustingFrame = true
        window.setFrame(targetFrame, display: true, animate: animated)
        isAdjustingFrame = false
    }

    private func revealWindow(fullyInsideScreen: Bool, animated: Bool) {
        guard !isAdjustingFrame,
              let window,
              appState?.isPetDocked == true,
              let visibleFrame = targetScreen(for: window)?.visibleFrame else { return }

        var origin = window.frame.origin
        let fullSize = CGSize(
            width: Constants.petWindowTotalWidth,
            height: Constants.petContentSize.height
        )
        if fullyInsideScreen {
            origin = clampedOrigin(origin, size: fullSize, visibleFrame: visibleFrame)
        }

        isAdjustingFrame = true
        window.setFrame(NSRect(origin: origin, size: fullSize), display: true, animate: animated)
        appState?.setPetDockSide(nil)
        isAdjustingFrame = false
    }

    private func targetScreen(for window: NSWindow) -> NSScreen? {
        window.screen ?? NSScreen.screens.max { lhs, rhs in
            let lhsIntersection = lhs.visibleFrame.intersection(window.frame)
            let rhsIntersection = rhs.visibleFrame.intersection(window.frame)
            return lhsIntersection.width * lhsIntersection.height
                < rhsIntersection.width * rhsIntersection.height
        }
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
    @State private var areActionButtonsVisible = false
    @State private var pendingSingleClick: DispatchWorkItem?
    @State private var hideActionButtonsTask: DispatchWorkItem?

    init(appState: AppState) {
        self.appState = appState
        _updateService = ObservedObject(wrappedValue: appState.updateService)
    }

    var body: some View {
        ZStack(alignment: .leading) {
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
                    onRightClick: {}
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

            PetActionButtons(
                appState: appState,
                isVisible: areActionButtonsVisible
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onHover { hovering in
            updateActionButtonsVisibility(hovering: hovering)
        }
        .onReceive(NotificationCenter.default.publisher(for: .collapsePetMenu)) { _ in
            hideActionButtonsTask?.cancel()
            areActionButtonsVisible = false
        }
        .onDisappear {
            hideActionButtonsTask?.cancel()
            hideActionButtonsTask = nil
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

        if appState.isObedientMode {
            appState.showInteractionSprite("得意", duration: 0.1)
            return
        }

        let task = DispatchWorkItem { [weak appState] in
            appState?.showInteractionSprite("愤怒", duration: 2)
        }
        pendingSingleClick = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: task)
    }

    private func updateActionButtonsVisibility(hovering: Bool) {
        hideActionButtonsTask?.cancel()
        hideActionButtonsTask = nil

        if hovering {
            withAnimation(.easeOut(duration: 0.16)) {
                areActionButtonsVisible = true
            }
            return
        }

        let task = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.18)) {
                areActionButtonsVisible = false
            }
            hideActionButtonsTask = nil
        }
        hideActionButtonsTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func handleDoubleClick() {
        pendingSingleClick?.cancel()
        pendingSingleClick = nil

        if appState.currentState == .reminder {
            appState.completeKegel()
            return
        }

        guard !appState.isObedientMode else { return }

        appState.activityEngine.triggerFlyUp()
    }
}
