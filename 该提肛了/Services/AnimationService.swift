import SwiftUI

/// Reusable animation presets for the pet and bubbles.
enum AnimationService {

    // MARK: - Pet Animations

    /// Gentle floating bobbing for idle state.
    static var idle: Animation {
        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }

    /// Quick wiggle when a group event is received.
    static var wiggle: Animation {
        .easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)
    }

    /// Scale up for reminder state.
    static var reminderPulse: Animation {
        .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
    }

    // MARK: - Bubble Animations

    /// Slide in from the right with fade.
    static var bubbleEnter: Animation {
        .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
    }

    /// Fade out for auto-dismiss.
    static var bubbleExit: Animation {
        .easeOut(duration: 0.3)
    }

    // MARK: - View Modifiers for Common Animations

    struct IdleModifier: ViewModifier {
        @State private var offset: CGFloat = 0

        func body(content: Content) -> some View {
            content
                .offset(y: offset)
                .onAppear {
                    withAnimation(AnimationService.idle) {
                        offset = -6
                    }
                }
        }
    }

    struct ReminderModifier: ViewModifier {
        @State private var scale: CGFloat = 1.0

        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(AnimationService.reminderPulse) {
                        scale = 1.08
                    }
                }
        }
    }

    struct WiggleModifier: ViewModifier {
        @State private var angle: Angle = .zero

        func body(content: Content) -> some View {
            content
                .rotationEffect(angle)
                .onAppear {
                    withAnimation(AnimationService.wiggle) {
                        angle = .degrees(8)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            angle = .zero
                        }
                    }
                }
        }
    }

    /// Short, deterministic success motion for the proud confirmation frame.
    /// Fixed-duration curves keep the result consistent on older macOS releases.
    struct ConfirmationModifier: ViewModifier {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var scale: CGFloat = 0.84
        @State private var offsetY: CGFloat = 5
        @State private var angle: Angle = .degrees(-3)

        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .offset(y: offsetY)
                .rotationEffect(angle)
                .onAppear {
                    guard !reduceMotion else {
                        scale = 1
                        offsetY = 0
                        angle = .zero
                        return
                    }

                    // Start on the next run-loop turn so the initial pose is
                    // committed before the success motion begins.
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.16)) {
                            scale = 1.08
                            offsetY = -4
                            angle = .degrees(2)
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            scale = 1
                            offsetY = 0
                            angle = .zero
                        }
                    }
                }
        }
    }

}

// MARK: - Convenience View Extensions

extension View {
    func idleAnimation() -> some View {
        modifier(AnimationService.IdleModifier())
    }

    func reminderPulseAnimation() -> some View {
        modifier(AnimationService.ReminderModifier())
    }

    func wiggleAnimation() -> some View {
        modifier(AnimationService.WiggleModifier())
    }

    func confirmationAnimation() -> some View {
        modifier(AnimationService.ConfirmationModifier())
    }
}
