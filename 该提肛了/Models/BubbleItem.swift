import Foundation

/// Bubble types and their display priority.
enum BubbleKind: Equatable {
    case reminder       // "该提肛了！" — highest priority, non-dismissable
    case groupEvent     // "XXX 已提肛！" — auto-dismiss after 5 seconds
    case chatMessage    // "XXX: message" — auto-dismiss after 5 seconds
}

/// Priority ordering for the bubble queue.
enum BubblePriority: Int, Comparable {
    case reminder = 0
    case groupEvent = 1
    case chatMessage = 2

    static func < (lhs: BubblePriority, rhs: BubblePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single bubble item in the display queue.
struct BubbleItem: Identifiable, Equatable {
    let id = UUID()
    let kind: BubbleKind
    let senderNickname: String?       // For group events & chat messages
    let senderPetEmoji: String?       // For group events & chat messages
    let senderAvatarURL: String?      // Avatar URL for group events & chat messages
    let message: String?              // For chat messages
    let timestamp: Date

    init(
        kind: BubbleKind,
        senderNickname: String? = nil,
        senderPetEmoji: String? = nil,
        senderAvatarURL: String? = nil,
        message: String? = nil,
        timestamp: Date = Date()
    ) {
        self.kind = kind
        self.senderNickname = senderNickname
        self.senderPetEmoji = senderPetEmoji
        self.senderAvatarURL = senderAvatarURL
        self.message = message
        self.timestamp = timestamp
    }

    var priority: BubblePriority {
        switch kind {
        case .reminder: return .reminder
        case .groupEvent: return .groupEvent
        case .chatMessage: return .chatMessage
        }
    }

    static func == (lhs: BubbleItem, rhs: BubbleItem) -> Bool {
        lhs.id == rhs.id
    }
}
