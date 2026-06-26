import SwiftUI

struct IntervalView: View {
    @Binding var intervalSeconds: Int
    var onNext: () -> Void
    var onBack: () -> Void

    private struct Preset: Identifiable {
        let id = UUID()
        let symbolName: String
        let label: String
        let seconds: Int
    }

    private let presets: [Preset] = [
        .init(symbolName: "hare.fill",    label: "10秒",  seconds: 10),
        .init(symbolName: "cup.and.saucer.fill", label: "5分钟",  seconds: 300),
        .init(symbolName: "clock.fill",   label: "20分钟", seconds: 1200),
        .init(symbolName: "book.fill",    label: "40分钟", seconds: 2400),
        .init(symbolName: "moon.fill",    label: "1小时",  seconds: 3600),
        .init(symbolName: "bed.double.fill", label: "2小时",  seconds: 7200),
    ]

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒" }
        let mins = seconds / 60
        let secs = seconds % 60
        return secs > 0 ? "\(mins) 分 \(secs) 秒" : "\(mins) 分钟"
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("提醒间隔")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.charcoalText)
                Text("你想多久活动一下？")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Large animated time display
            VStack(spacing: 2) {
                Text("每")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatInterval(intervalSeconds))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .animation(.spring(response: 0.3), value: intervalSeconds)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accent.opacity(0.06))
            )

            // SF Symbol preset cards in horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presets) { preset in
                        PresetCardView(
                            symbolName: preset.symbolName,
                            label: preset.label,
                            isSelected: intervalSeconds == preset.seconds,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    intervalSeconds = preset.seconds
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            // Styled slider for custom values
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(intervalSeconds) },
                        set: { intervalSeconds = Constants.normalizedIntervalSeconds(Int(($0 / Constants.intervalStep).rounded() * Constants.intervalStep)) }
                    ),
                    in: Constants.intervalRange,
                    step: Constants.intervalStep
                )
                .tint(.accent)

                HStack {
                    Text("10秒").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("120分钟").font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                Button("返回") { onBack() }
                    .buttonStyle(ClaySecondaryButtonStyle())
                Button("继续") { onNext() }
                    .buttonStyle(ClayPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Preset Card

private struct PresetCardView: View {
    let symbolName: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 26))
                    .foregroundColor(isSelected ? .accent : .secondary)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .accent : .secondary)
            }
            .frame(width: 72, height: 78)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.claySurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.05), radius: 6, x: 2, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: isSelected ? Color.accent.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : (isHovering ? 1.03 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { isHovering = $0 }
    }
}
