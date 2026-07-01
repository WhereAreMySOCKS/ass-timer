import SwiftUI

/// A ring of SF Symbol icon buttons that appear when hovering over the pet.
/// No visible text — icons only, with accessibility labels.
struct PetActionButtons: View {
    @ObservedObject var appState: AppState
    @Binding var isVisible: Bool

    private var totalUnreadMessages: Int {
        appState.chatUnreadCounts.values.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 10) {
            ActionButton(
                systemName: "gearshape",
                label: "设置",
                action: { NotificationCenter.default.post(name: .showSettings, object: nil) }
            )
            ActionButton(
                systemName: "message",
                label: "发言",
                badgeCount: totalUnreadMessages,
                action: { NotificationCenter.default.post(name: .showChat, object: nil) }
            )
            ActionButton(
                systemName: "trophy",
                label: "奖杯",
                action: { NotificationCenter.default.post(name: .showLeaderboard, object: nil) }
            )
            ActionButton(
                systemName: "power",
                label: "退出",
                action: {
                    appState.onAppTerminate()
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

struct ActionButton: View {
    let systemName: String
    let label: String
    var badgeCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 28, height: 28)

                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 13, minHeight: 13)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 5, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .accessibilityLabel(
            badgeCount > 0 ? "\(label)，\(badgeCount)条未读消息" : label
        )
        .help(label)
    }
}
