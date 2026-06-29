import SwiftUI

// MARK: - App Colors

extension Color {
    /// Primary accent color — a health/fitness teal-green
    static let accent = Color(red: 0.0, green: 0.7, blue: 0.6)

    /// Bubble background color
    static let bubbleBackground = Color(NSColor.controlBackgroundColor)

    /// Warm paper surface for comic-style speech bubbles.
    static let comicBubblePaper = Color(red: 1.0, green: 0.985, blue: 0.94)

    /// Ink color for comic outlines and primary bubble copy.
    static let comicInk = Color(red: 0.13, green: 0.105, blue: 0.09)

    /// Self-highlight color for leaderboard
    static let selfHighlight = Color.accent.opacity(0.15)

    // MARK: Claymorphism Palette

    /// Warm off-white page background
    static let clayBackground = Color(red: 0.957, green: 0.965, blue: 0.961)

    /// Card / elevated surface
    static let claySurface = Color.white

    /// Secondary accent — warm coral for destructive/secondary CTAs
    static let coral = Color(red: 0.941, green: 0.365, blue: 0.361)

    /// Dark charcoal for primary text (not pure black)
    static let charcoalText = Color(red: 0.18, green: 0.18, blue: 0.20)
}

// MARK: - View Modifiers

extension View {
    /// Comic speech-bubble styling for pet reminders and group events.
    func bubbleStyle() -> some View {
        self
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .background(
                ZStack {
                    ComicBubbleShape()
                        .fill(Color.black.opacity(0.18))
                        .offset(x: 5, y: 6)

                    ComicBubbleShape()
                        .fill(Color.comicBubblePaper)

                    ComicBubbleShape()
                        .stroke(Color.comicInk, style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))

                    ComicBubbleHighlightShape()
                        .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .padding(.horizontal, 14)
                        .padding(.top, 9)
                        .padding(.bottom, 26)
                }
            )
            .foregroundStyle(Color.comicInk)
    }

    /// Card-like styling for onboarding panels
    func cardStyle() -> some View {
        self
            .padding(24)
            .background(Color.bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }

    // MARK: Claymorphism

    /// Claymorphism card: soft 3D raised surface with inner highlight and dual shadows
    func clayCard(cornerRadius: CGFloat = 20, isSelected: Bool = false) -> some View {
        modifier(ClayCardModifier(cornerRadius: cornerRadius, isSelected: isSelected))
    }
}

// MARK: - Claymorphism Card Modifier

struct ClayCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var isSelected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.claySurface)
                    // Inner top-left highlight (claymorphism signature)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
            )
            // Outer shadow — darker bottom-right
            .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.08), radius: 10, x: 3, y: 5)
            // Subtle inner shadow illusion
            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            // Selected glow ring
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: isSelected ? Color.accent.opacity(0.25) : Color.clear, radius: 8, x: 0, y: 0)
    }
}

// MARK: - Claymorphism Button Styles

/// Primary CTA — teal filled with shadow and spring press
struct ClayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accent)
                    .shadow(color: Color.accent.opacity(0.35), radius: 8, x: 2, y: 4)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Secondary / bordered button — white with teal border
struct ClaySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.medium)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.claySurface)
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 2, y: 3)
            )
            .foregroundColor(.accent)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accent.opacity(0.25), lineWidth: 1.2)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Subtle text link — for skip/back actions
struct ClaySubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.secondary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Primary action inside comic speech bubbles.
struct ComicActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .foregroundStyle(Color.comicBubblePaper)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.accent)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.comicInk, lineWidth: 2.4)
                    )
                    .shadow(color: Color.comicInk.opacity(0.24), radius: 0, x: 3, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - String Helpers

extension String {
    var sanitized: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValidNickname: Bool {
        let sanitized = self.sanitized
        return sanitized.count >= Constants.nicknameMinLength
            && sanitized.count <= Constants.nicknameMaxLength
    }

    var isValidInviteCode: Bool {
        self.sanitized.uppercased().count == Constants.inviteCodeLength
    }
}

// MARK: - Remote Avatar

extension String {
    var apiAssetURL: URL? {
        if hasPrefix("http://") || hasPrefix("https://") {
            return URL(string: self)
        }
        return URL(string: "\(Constants.apiBaseURL)\(self)")
    }
}

struct AvatarImageView: View {
    let avatarURL: String
    var size: CGFloat = 28

    @State private var image: NSImage?

    private var resolvedURL: URL? {
        avatarURL.apiAssetURL
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .padding(size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .task(id: resolvedURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let resolvedURL else {
            image = nil
            return
        }

        if let cached = LocalCacheManager.shared.cachedAvatarImage(for: resolvedURL) {
            image = cached
            return
        }

        image = await LocalCacheManager.shared.loadAvatarImage(from: resolvedURL)
    }
}

// MARK: - Comic Bubble Shape

struct ComicBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tailHeight: CGFloat = 18
        let tailWidth: CGFloat = 34
        let radius: CGFloat = 22
        let bodyMaxY = rect.maxY - tailHeight
        let tailTipX = rect.midX
        let tailBaseLeft = tailTipX - tailWidth * 0.42
        let tailBaseRight = tailTipX + tailWidth * 0.58

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.minY + 2),
            control: CGPoint(x: rect.midX, y: rect.minY - 5)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY + 3)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyMaxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: bodyMaxY),
            control: CGPoint(x: rect.maxX + 1, y: bodyMaxY - 1)
        )
        path.addLine(to: CGPoint(x: tailBaseRight, y: bodyMaxY))
        path.addQuadCurve(
            to: CGPoint(x: tailTipX, y: rect.maxY),
            control: CGPoint(x: tailTipX + 11, y: bodyMaxY + 11)
        )
        path.addQuadCurve(
            to: CGPoint(x: tailBaseLeft, y: bodyMaxY - 1),
            control: CGPoint(x: tailTipX - 11, y: bodyMaxY + 8)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: bodyMaxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: bodyMaxY - radius),
            control: CGPoint(x: rect.minX, y: bodyMaxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        return path
    }
}

struct ComicBubbleHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 16, y: rect.minY + 8))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 18, y: rect.minY + 7),
            control: CGPoint(x: rect.midX, y: rect.minY - 2)
        )
        return path
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showLeaderboard = Notification.Name("ass_timer_show_leaderboard")
    static let showGroupInfo = Notification.Name("ass_timer_show_group_info")
    static let showIntervalModifier = Notification.Name("ass_timer_show_interval_modifier")
    static let showSettings = Notification.Name("ass_timer_show_settings")
    static let showChat = Notification.Name("ass_timer_show_chat")
    static let selectChatGroup = Notification.Name("ass_timer_select_chat_group")
    static let petWindowDidMove = Notification.Name("ass_timer_pet_window_did_move")
    static let chatMessageReceived = Notification.Name("chatMessageReceived")
    static let localDataCleared = Notification.Name("ass_timer_local_data_cleared")
}
