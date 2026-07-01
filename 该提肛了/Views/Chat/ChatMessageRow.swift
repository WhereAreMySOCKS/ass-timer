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
        guard let date = parseServerDate(iso) else {
            return iso
        }
        let display = DateFormatter()
        display.locale = Locale(identifier: "zh_CN")
        display.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM-dd HH:mm"
        return display.string(from: date)
    }

    private func parseServerDate(_ iso: String) -> Date? {
        let candidates = iso.hasSuffix("Z") || iso.contains("+")
            ? [iso]
            : [iso + "Z", iso]

        for candidate in candidates {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: candidate) {
                return date
            }
            if let date = ISO8601DateFormatter().date(from: candidate) {
                return date
            }
        }
        return nil
    }
}
