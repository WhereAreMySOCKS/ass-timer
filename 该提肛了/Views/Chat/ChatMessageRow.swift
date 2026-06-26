import SwiftUI

/// A single chat message bubble.
struct ChatMessageRow: View {
    let message: ChatMessageResponse
    let isSelf: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if isSelf { Spacer(minLength: 40) }

            if !isSelf {
                AvatarImageView(avatarURL: message.avatar_url, size: 28)
            }

            VStack(alignment: isSelf ? .trailing : .leading, spacing: 2) {
                if !isSelf {
                    Text(message.nickname)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelf
                            ? Color.accent.opacity(0.85)
                            : Color(white: 0.93)
                    )
                    .foregroundColor(isSelf ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(formatTime(message.created_at))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !isSelf { Spacer(minLength: 40) }

            if isSelf {
                AvatarImageView(avatarURL: message.avatar_url, size: 28)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso)
                ?? ISO8601DateFormatter().date(from: iso) else {
            return ""
        }
        let display = DateFormatter()
        display.dateFormat = "HH:mm"
        return display.string(from: date)
    }
}
