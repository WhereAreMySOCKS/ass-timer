import SwiftUI

/// Pet action buttons arranged along the right-side arc, shown on hover.
struct PetActionButtons: View {
    @ObservedObject var appState: AppState
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalUnreadMessages: Int {
        appState.chatUnreadCounts.values.reduce(0, +)
    }

    private var arcPositions: [CGPoint] {
        let rightArc: [CGPoint] = [
            CGPoint(x: 135, y: 48),
            CGPoint(x: 148, y: 76),
            CGPoint(x: 152, y: 106),
            CGPoint(x: 148, y: 136),
            CGPoint(x: 135, y: 164),
        ]
        let spriteCenterX = (Constants.petContentSize.width - Constants.petSpriteSize.width) / 2
            + Constants.petSpriteSize.width / 2

        guard appState.petDockSide == .right else { return rightArc }

        return rightArc.map { pt in
            CGPoint(x: spriteCenterX + (spriteCenterX - pt.x), y: pt.y)
        }
    }

    private struct ButtonConfig {
        let systemName: String
        let label: String
        let badgeCount: Int
        let isSelected: Bool
        let isDisabled: Bool
        let action: () -> Void
    }

    private var buttons: [ButtonConfig] {
        [
            ButtonConfig(
                systemName: "gearshape", label: "设置",
                badgeCount: 0, isSelected: false, isDisabled: false
            ) {
                NotificationCenter.default.post(name: .showSettings, object: nil)
            },
            ButtonConfig(
                systemName: "message", label: "发言",
                badgeCount: totalUnreadMessages, isSelected: false, isDisabled: false
            ) {
                NotificationCenter.default.post(name: .showChat, object: nil)
            },
            ButtonConfig(
                systemName: "trophy", label: "奖杯",
                badgeCount: 0, isSelected: false, isDisabled: false
            ) {
                NotificationCenter.default.post(name: .showLeaderboard, object: nil)
            },
            ButtonConfig(
                systemName: appState.isObedientMode ? "leaf.fill" : "leaf",
                label: appState.isObedientMode ? "切换到普通模式" : "开启听话模式",
                badgeCount: 0, isSelected: appState.isObedientMode,
                isDisabled: appState.isLeavingObedientMode
            ) {
                appState.toggleObedientMode()
            },
            ButtonConfig(
                systemName: "power", label: "退出",
                badgeCount: 0, isSelected: false, isDisabled: false
            ) {
                appState.onAppTerminate()
                NSApplication.shared.terminate(nil)
            },
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(buttons.enumerated()), id: \.offset) { index, btn in
                PetMenuButton(
                    systemName: btn.systemName,
                    label: btn.label,
                    badgeCount: btn.badgeCount,
                    isSelected: btn.isSelected,
                    action: btn.action
                )
                .disabled(btn.isDisabled)
                .position(arcPositions[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeOut(duration: 0.16), value: isVisible)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("宠物操作菜单")
    }
}

private struct PetMenuButton: View {
    let systemName: String
    let label: String
    var badgeCount = 0
    var isSelected = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isSelected
                            ? Color.orange.opacity(isHovering ? 0.24 : 0.16)
                            : Color.primary.opacity(isHovering ? 0.11 : 0.001)
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.orange : Color.primary)
                    .frame(width: 44, height: 44)

                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 15, y: -15)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(PetMenuButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(badgeCount > 0 ? "\(label)，\(badgeCount)条未读消息" : label)
        .accessibilityValue(isSelected ? "已开启" : "")
        .help(label)
    }
}

private struct PetMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
