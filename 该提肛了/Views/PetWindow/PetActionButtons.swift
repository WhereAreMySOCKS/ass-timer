import SwiftUI

/// A ring of SF Symbol icon buttons that appear when hovering over the pet.
/// No visible text — icons only, with accessibility labels.
struct PetActionButtons: View {
    @ObservedObject var appState: AppState
    @Binding var isVisible: Bool

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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .accessibilityLabel(label)
        .help(label)
    }
}
