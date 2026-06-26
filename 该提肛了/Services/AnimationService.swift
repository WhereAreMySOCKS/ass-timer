import SwiftUI

/// Reusable animation presets for the pet and bubbles.
enum AnimationService {

    // MARK: - Pet Animations

    /// Gentle floating bobbing for idle state.
    static var idle: Animation {
        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }

    /// Bounce on single click.
    static var bounce: Animation {
        .spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)
    }

    /// Full flip on double click.
    static var flip: Animation {
        .easeInOut(duration: 0.6)
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

    struct BounceModifier: ViewModifier {
        @State private var scale: CGFloat = 1.0

        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .onTapGesture(count: 1) {
                    withAnimation(AnimationService.bounce) {
                        scale = 0.8
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                            scale = 1.0
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
}
