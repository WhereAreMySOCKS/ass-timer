import SwiftUI

/// The emoji/image pet display with animation states.
struct PetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggleAngle: Angle = .zero
    @State private var clickScale: CGFloat = 1
    @State private var clickOffsetY: CGFloat = 0
    @State private var clickResetTask: DispatchWorkItem?

    var body: some View {
        let content = Group {
            if let customActionSlot,
               let customImage = appState.customActionImage(for: customActionSlot) {
                shadowedPet {
                    Image(nsImage: customImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Constants.petSpriteSize.width, height: Constants.petSpriteSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else if let spriteName = spriteNameForCurrentState,
               let spriteImage = SpriteLoader.loadSprite(named: spriteName) {
                shadowedPet {
                    Image(nsImage: spriteImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(x: shouldFlipSprite ? -1 : 1, y: 1)
                        .frame(width: Constants.petSpriteSize.width, height: Constants.petSpriteSize.height)
                }
            } else if let imageName = appState.config.petImageName,
                      let nsImage = NSImage(named: imageName) {
                shadowedPet {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Constants.petSpriteSize.width, height: Constants.petSpriteSize.height)
                }
            } else {
                shadowedPet {
                    Text(appState.config.petEmoji ?? "🐱")
                        .font(.system(size: 128))
                }
            }
        }

        applyAnimation(content)
            .rotationEffect(wiggleAngle)
            .scaleEffect(clickScale)
            .offset(y: clickOffsetY)
            .onChange(of: appState.interactionAnimationID) { animationID in
                guard animationID != nil else { return }
                playClickResponse()
            }
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
            .onDisappear {
                clickResetTask?.cancel()
                clickResetTask = nil
            }
    }

    /// Timer states win over interaction and activity states so reminder feedback is never hidden.
    private var customActionSlot: CustomActionSlot? {
        switch appState.currentState {
        case .reminder:
            return .reminder
        case .waitConfirm:
            return .completion
        default:
            if appState.interactionSpriteFrame == "愤怒" {
                return .interaction
            }
            if appState.activityEngine.activityState == .napping {
                return .nap
            }
            return nil
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
            if activity == .walking || activity == .flying || activity == .napping {
                content
            } else {
                content.idleAnimation()
            }
        case .reminder:
            content.reminderPulseAnimation()
        case .waitConfirm:
            content.confirmationAnimation()
        case .reset:
            content
        }
    }

    /// Draw the shadow inside the transparent pet window instead of relying on
    /// NSWindow's shape shadow, which is unreliable for borderless transparent
    /// windows on older macOS releases.
    private func shadowedPet<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
                .colorMultiply(.black)
                .opacity(0.24)
                .blur(radius: 5)
                .offset(x: 0, y: 4)

            content()
        }
    }

    private func playClickResponse() {
        clickResetTask?.cancel()

        guard !reduceMotion else {
            clickScale = 1
            clickOffsetY = 0
            return
        }

        // Fixed-duration curves are stable across supported macOS versions;
        // SwiftUI spring behavior has varied between system releases.
        withAnimation(.easeOut(duration: 0.09)) {
            clickScale = 0.88
            clickOffsetY = 4
        }

        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.18)) {
                clickScale = 1
                clickOffsetY = 0
            }
            clickResetTask = nil
        }
        clickResetTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09, execute: task)
    }
}
