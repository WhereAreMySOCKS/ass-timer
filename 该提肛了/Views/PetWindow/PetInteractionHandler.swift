import SwiftUI
import AppKit

/// Custom NSView subclass to detect mouse events and hover.
/// Extracted to top-level with explicit @objc name to avoid KVO class-pair allocation
/// failures under Swift 6 MainActor isolation.
@objc(PetInteractionView)
final class PetInteractionView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        if let trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else if event.clickCount == 1 {
            onSingleClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverEnter?()
    }

    override func mouseExited(with event: NSEvent) {
        onHoverExit?()
    }
}

/// Handles mouse/trackpad interactions on the pet: clicks, drag, hover, and right-click menu.
struct PetInteractionHandler: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void
    let onRightClick: () -> Void
    var onHoverEnter: (() -> Void)?
    var onHoverExit: (() -> Void)?

    func makeNSView(context: Context) -> PetInteractionView {
        let view = PetInteractionView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        view.onRightClick = onRightClick
        view.onHoverEnter = onHoverEnter
        view.onHoverExit = onHoverExit
        view.setupTrackingArea()
        return view
    }

    func updateNSView(_ nsView: PetInteractionView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
        nsView.onRightClick = onRightClick
        nsView.onHoverEnter = onHoverEnter
        nsView.onHoverExit = onHoverExit
    }
}
