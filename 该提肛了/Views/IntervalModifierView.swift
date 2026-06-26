import SwiftUI

/// Standalone view for modifying the reminder interval.
/// Reuses the slider + preset pattern from IntervalView.
struct IntervalModifierView: View {
    @ObservedObject var appState: AppState
    var onDismiss: () -> Void

    @State private var intervalSeconds: Double
    @State private var isSaved = false
    private let presets = [10, 30, 60, 300, 600, 1200, 2400, 3600, 7200]
    private let presetColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    init(appState: AppState, onDismiss: @escaping () -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
        _intervalSeconds = State(initialValue: Double(appState.config.intervalSeconds))
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) 秒"
        } else {
            let mins = seconds / 60
            let secs = seconds % 60
            return secs > 0 ? "\(mins) 分 \(secs) 秒" : "\(mins) 分钟"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("提醒间隔")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if isSaved {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.accent)
                    Text("已保存！")
                        .font(.subheadline)
                }
                Spacer()
            } else {
                VStack(spacing: 4) {
                    Text("每")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatInterval(Int(intervalSeconds)))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.accent)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    Text("提醒一次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { intervalSeconds },
                            set: { intervalSeconds = Double(Constants.normalizedIntervalSeconds(Int(($0 / Constants.intervalStep).rounded() * Constants.intervalStep))) }
                        ),
                        in: Constants.intervalRange,
                        step: Constants.intervalStep
                    )

                    HStack {
                        Text("10 秒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("120 分钟")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                LazyVGrid(columns: presetColumns, spacing: 8) {
                    ForEach(presets, id: \.self) { secs in
                        Button(formatInterval(secs)) {
                            intervalSeconds = Double(secs)
                        }
                        .buttonStyle(.bordered)
                        .tint(Int(intervalSeconds) == secs ? .accent : .secondary)
                        .background(Int(intervalSeconds) == secs ? Color.accent.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .controlSize(.small)
                    }
                }

                HStack {
                    Text("最短支持 10 秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    Button("取消") { onDismiss() }
                        .buttonStyle(.bordered)

                    Button("保存") {
                        appState.modifyInterval(Constants.normalizedIntervalSeconds(Int(intervalSeconds)))
                        isSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            onDismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(15)
        .frame(width: 225, height: 240)
    }
}
