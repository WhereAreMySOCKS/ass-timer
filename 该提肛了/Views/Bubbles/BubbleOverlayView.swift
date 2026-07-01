import SwiftUI
import AppKit

/// A transparent NSView that passes through mouse events for non-interactive areas
/// while still delivering events to interactive SwiftUI content (buttons, etc.).
@objc(PassthroughView)
final class PassthroughView: NSView {
    /// The NSHostingView containing the SwiftUI bubble content.
    weak var hostedView: NSView?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hostedView else { return nil }
        let localPoint = hostedView.convert(point, from: self)
        let hit = hostedView.hitTest(localPoint)
        // If the hit is the hosting view's root view or nil (transparent area),
        // pass through to windows behind. If it hit a real interactive subview,
        // deliver the event there.
        if hit == hostedView || hit == nil {
            return nil
        }
        return hit
    }
}

/// Custom NSWindow for bubble overlay — uses PassthroughView as its content view.
final class PassthroughWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Sets the hosting view as a child of a PassthroughView so that mouse events
    /// pass through transparent areas to windows behind.
    func setHostedView(_ hostingView: NSView) {
        // SwiftUI controls frequently hit-test as the NSHostingView itself.
        // Using PassthroughView here made the reminder button pass clicks through
        // the overlay, so keep the hosting view as the real content view.
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }
}

/// Non-dismissable reminder bubble with completion and skip actions.
struct ReminderBubbleView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.comicBubblePaper)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Color.coral))
                    .overlay(Circle().stroke(Color.comicInk, lineWidth: 1))

                Text("该提肛了！")
                    .font(.system(size: 13, weight: .black, design: .rounded))
            }

            Text("是时候做凯格尔运动了")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.comicInk.opacity(0.72))

            HStack(spacing: 6) {
                Button(action: {
                    appState.completeKegel()
                }) {
                    Text("已提")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ComicActionButtonStyle())

                Button(action: {
                    appState.skipKegel()
                }) {
                    Text("等会")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ComicSecondaryActionButtonStyle())
                .help("跳过本次，下次在当前间隔的一半时间后提醒")
            }
        }
        .frame(width: 150)
        .bubbleStyle()
    }
}

/// Auto-dismissing group event bubble: "XXX 已提肛！"
struct GroupEventBubbleView: View {
    let item: BubbleItem

    var body: some View {
        HStack(spacing: 10) {
            avatarOrEmoji

            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.senderNickname ?? "某人") 已提肛！")
                    .font(.system(size: 17, weight: .black, design: .rounded))

                Text(item.timestamp, style: .time)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.comicInk.opacity(0.58))
            }
        }
        .frame(width: 230, alignment: .leading)
        .bubbleStyle()
    }

    @ViewBuilder
    private var avatarOrEmoji: some View {
        if let avatarURL = item.senderAvatarURL {
            AvatarImageView(avatarURL: avatarURL, size: 36)
                .overlay(Circle().stroke(Color.comicInk, lineWidth: 2))
        } else {
            Text(item.senderPetEmoji ?? "!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.8)))
                .overlay(Circle().stroke(Color.comicInk, lineWidth: 2))
        }
    }
}

/// Chat message bubble: shows sender + message preview, auto-dismisses.
struct ChatBubbleView: View {
    let item: BubbleItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 8) {
                avatarOrEmoji

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.senderNickname ?? "群友")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.comicInk.opacity(0.7))

                    Text(item.message ?? "")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.comicInk)
                        .lineLimit(2)
                        .frame(maxWidth: 180, alignment: .leading)
                }
            }
            .frame(width: 220, alignment: .leading)
            .bubbleStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开来自\(item.senderNickname ?? "群友")的群聊消息")
        .help("打开群聊")
    }

    @ViewBuilder
    private var avatarOrEmoji: some View {
        if let avatarURL = item.senderAvatarURL {
            AvatarImageView(avatarURL: avatarURL, size: 30)
                .overlay(Circle().stroke(Color.comicInk, lineWidth: 1.5))
        } else {
            Text(item.senderPetEmoji ?? "💬")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.8)))
                .overlay(Circle().stroke(Color.comicInk, lineWidth: 1.5))
        }
    }
}

/// Container that stacks bubbles in priority order at the top-right of the screen.
struct BubbleOverlayView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(appState.bubbles) { bubble in
                Group {
                    switch bubble.kind {
                    case .reminder:
                        ReminderBubbleView(appState: appState)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))

                    case .groupEvent:
                        GroupEventBubbleView(item: bubble)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                    case .chatMessage:
                        ChatBubbleView(item: bubble) {
                            guard let groupID = bubble.groupID else { return }
                            appState.removeBubble(id: bubble.id)
                            NotificationCenter.default.post(
                                name: .showChat,
                                object: nil,
                                userInfo: ["groupID": groupID]
                            )
                        }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: appState.bubbles.map(\.id))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
