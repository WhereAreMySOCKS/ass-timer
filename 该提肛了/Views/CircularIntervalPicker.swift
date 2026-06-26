import SwiftUI

struct CircularIntervalPicker: View {
    @Binding var seconds: Int

    private var normalized: Int {
        Constants.normalizedIntervalSeconds(seconds)
    }

    private var progress: Double {
        let minValue = Constants.intervalRange.lowerBound
        let maxValue = Constants.intervalRange.upperBound
        return (Double(normalized) - minValue) / (maxValue - minValue)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth: CGFloat = 14

            ZStack {
                Circle()
                    .stroke(Color.onboardingMuted, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.onboardingAccent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text("每")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.onboardingSecondaryText)
                    Text(formatInterval(normalized))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.onboardingText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.onboardingAccent, lineWidth: 4))
                    .offset(y: -size / 2 + lineWidth / 2)
                    .rotationEffect(.degrees(progress * 360))
            }
            .padding(lineWidth / 2)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                    .onChanged { value in
                        updateValue(from: value.location, in: proxy.size)
                    }
            )
        }
        .accessibilityLabel("提醒间隔")
        .accessibilityValue(formatInterval(normalized))
    }

    private func updateValue(from point: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        let ratio = Double(angle / (2 * .pi))
        let currentRatio = progress
        let minValue = Constants.intervalRange.lowerBound
        let maxValue = Constants.intervalRange.upperBound
        let clampedRatio: Double

        if currentRatio > 0.85 && ratio < 0.15 {
            clampedRatio = 1
        } else if currentRatio < 0.15 && ratio > 0.85 {
            clampedRatio = 0
        } else {
            clampedRatio = ratio
        }

        let rawValue = minValue + clampedRatio * (maxValue - minValue)
        let stepped = Int((rawValue / Constants.intervalStep).rounded() * Constants.intervalStep)
        let nextSeconds = Constants.normalizedIntervalSeconds(stepped)
        if nextSeconds != seconds {
            seconds = nextSeconds
        }
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒" }
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs > 0 { return "\(minutes) 分 \(secs) 秒" }
        return "\(minutes) 分钟"
    }
}
