import SwiftUI

/// The emoji/image pet display with animation states.
struct PetView: View {
    @ObservedObject var appState: AppState
    @State private var wiggleAngle: Angle = .zero

    var body: some View {
        let content = Group {
            if let spriteName = spriteNameForCurrentState,
               let spriteImage = SpriteLoader.loadSprite(named: spriteName) {
                Image(nsImage: spriteImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: shouldFlipSprite ? -1 : 1, y: 1)
                    .frame(width: Constants.petSpriteSize.width, height: Constants.petSpriteSize.height)
            } else if let imageName = appState.config.petImageName,
                      let nsImage = NSImage(named: imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Constants.petSpriteSize.width, height: Constants.petSpriteSize.height)
            } else {
                Text(appState.config.petEmoji ?? "🐱")
                    .font(.system(size: 128))
            }
        }

        applyAnimation(content)
            .rotationEffect(wiggleAngle)
            .onChange(of: appState.groupEventAnimationID) { _ in
                guard appState.groupEventAnimationID != nil else { return }
                withAnimation(AnimationService.wiggle) {
                    wiggleAngle = .degrees(8)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        wiggleAngle = .zero
                    }
                }
            }

    }

    private var spriteNameForCurrentState: String? {
        switch appState.currentState {
        case .reminder:
            return "停止"
        case .waitConfirm:
            return "得意"
        default:
            return appState.interactionSpriteFrame ?? appState.currentSpriteFrame
        }
    }

    private var shouldFlipSprite: Bool {
        appState.currentState != .reminder
            && (
                (appState.activityEngine.activityState == .walking && appState.activityEngine.isWalkingLeft)
                || (appState.activityEngine.activityState == .flying && appState.activityEngine.isFlyingLeft)
            )
    }

    @ViewBuilder
    private func applyAnimation<Content: View>(_ content: Content) -> some View {
        switch appState.currentState {
        case .idle:
            content.idleAnimation()
        case .running:
            // No idle bob when walking or flying — window is already moving
            let activity = appState.activityEngine.activityState
            if activity == .walking || activity == .flying {
                content
            } else {
                content.idleAnimation()
            }
        case .reminder:
            content.reminderPulseAnimation()
        case .waitConfirm:
            content.scaleEffect(0.9)
        case .reset:
            content
        }
    }

    /// Trigger a bounce animation (called from interaction handler).
    func playBounce() {
        withAnimation(AnimationService.bounce) {
            appState.isAnimating = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                appState.isAnimating = false
            }
        }
    }

    /// Trigger a flip animation (called from interaction handler).
    func playFlip() {
        withAnimation(AnimationService.flip) {
            appState.isAnimating = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.1)) {
                appState.isAnimating = false
            }
        }
    }
}
