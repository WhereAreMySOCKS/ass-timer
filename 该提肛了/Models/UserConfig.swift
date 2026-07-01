import Foundation

/// A single joined group stored in UserConfig.
struct JoinedGroup: Codable, Identifiable, Equatable {
    var groupID: String
    var groupName: String
    var inviteCode: String
    var id: String { groupID }
}

/// User-configurable pet states that may display a local photo instead of a bundled sprite.
enum CustomActionSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case reminder
    case completion
    case nap
    case interaction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reminder: return "提醒"
        case .completion: return "完成"
        case .nap: return "睡觉"
        case .interaction: return "单击互动"
        }
    }

    var detail: String {
        switch self {
        case .reminder: return "提醒出现时"
        case .completion: return "完成提肛后"
        case .nap: return "宠物趴下时"
        case .interaction: return "单击宠物后"
        }
    }

    var systemImage: String {
        switch self {
        case .reminder: return "bell.fill"
        case .completion: return "checkmark.circle.fill"
        case .nap: return "moon.zzz.fill"
        case .interaction: return "hand.tap.fill"
        }
    }

    var defaultSpriteName: String {
        switch self {
        case .reminder: return "停止"
        case .completion: return "得意"
        case .nap: return "趴"
        case .interaction: return "愤怒"
        }
    }
}

/// Files belonging to one custom action photo. Paths are relative to the app-owned media folder.
struct CustomActionMediaEntry: Codable, Equatable, Sendable {
    var sourceFileName: String
    var backgroundFileName: String
    var foregroundFileName: String?
    var removesBackground: Bool
    var revision: UUID
}

/// Codable wrapper keeps the JSON shape stable and avoids non-string dictionary keys.
struct CustomActionMediaConfig: Codable, Equatable, Sendable {
    var reminder: CustomActionMediaEntry?
    var completion: CustomActionMediaEntry?
    var nap: CustomActionMediaEntry?
    var interaction: CustomActionMediaEntry?

    subscript(slot: CustomActionSlot) -> CustomActionMediaEntry? {
        get {
            switch slot {
            case .reminder: return reminder
            case .completion: return completion
            case .nap: return nap
            case .interaction: return interaction
            }
        }
        set {
            switch slot {
            case .reminder: reminder = newValue
            case .completion: completion = newValue
            case .nap: nap = newValue
            case .interaction: interaction = newValue
            }
        }
    }
}

/// Codable user configuration persisted to UserDefaults.
struct UserConfig: Codable {
    var userID: String?
    var nickname: String?
    var petEmoji: String?
    var petImageName: String?
    var avatarURL: String?
    var intervalSeconds: Int = 2400
    var customActionMedia = CustomActionMediaConfig()

    /// Multi-group support: all groups the user has joined.
    var joinedGroups: [JoinedGroup] = []

    var localEventCount: Int = 0
    var onboardingComplete: Bool = false
    var windowOriginX: CGFloat?
    var windowOriginY: CGFloat?
    var lastReminderTimestamp: TimeInterval?

    /// Convenience: the first (primary) group ID.
    var primaryGroupID: String? { joinedGroups.first?.groupID }

    /// Convenience: whether the user has any group membership.
    var hasGroup: Bool { !joinedGroups.isEmpty }

    // MARK: - Backward-compatible migration

    /// Legacy keys that may exist in old saved configs.
    private enum CodingKeys: String, CodingKey {
        case userID, nickname, petEmoji, petImageName, avatarURL
        case intervalSeconds, joinedGroups, localEventCount
        case customActionMedia
        case onboardingComplete, windowOriginX, windowOriginY
        case lastReminderTimestamp
        // Legacy single-group keys
        case groupID, groupName, inviteCode
    }

    init(
        userID: String? = nil,
        nickname: String? = nil,
        petEmoji: String? = nil,
        petImageName: String? = nil,
        avatarURL: String? = nil,
        intervalSeconds: Int = 2400,
        customActionMedia: CustomActionMediaConfig = CustomActionMediaConfig(),
        joinedGroups: [JoinedGroup] = [],
        localEventCount: Int = 0,
        onboardingComplete: Bool = false,
        windowOriginX: CGFloat? = nil,
        windowOriginY: CGFloat? = nil,
        lastReminderTimestamp: TimeInterval? = nil
    ) {
        self.userID = userID
        self.nickname = nickname
        self.petEmoji = petEmoji
        self.petImageName = petImageName
        self.avatarURL = avatarURL
        self.intervalSeconds = intervalSeconds
        self.customActionMedia = customActionMedia
        self.joinedGroups = joinedGroups
        self.localEventCount = localEventCount
        self.onboardingComplete = onboardingComplete
        self.windowOriginX = windowOriginX
        self.windowOriginY = windowOriginY
        self.lastReminderTimestamp = lastReminderTimestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        petEmoji = try container.decodeIfPresent(String.self, forKey: .petEmoji)
        petImageName = try container.decodeIfPresent(String.self, forKey: .petImageName)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        intervalSeconds = try container.decodeIfPresent(Int.self, forKey: .intervalSeconds) ?? 2400
        customActionMedia = try container.decodeIfPresent(
            CustomActionMediaConfig.self,
            forKey: .customActionMedia
        ) ?? CustomActionMediaConfig()
        joinedGroups = try container.decodeIfPresent([JoinedGroup].self, forKey: .joinedGroups) ?? []
        localEventCount = try container.decodeIfPresent(Int.self, forKey: .localEventCount) ?? 0
        onboardingComplete = try container.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
        windowOriginX = try container.decodeIfPresent(CGFloat.self, forKey: .windowOriginX)
        windowOriginY = try container.decodeIfPresent(CGFloat.self, forKey: .windowOriginY)
        lastReminderTimestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .lastReminderTimestamp)

        // Migrate legacy single-group fields
        if joinedGroups.isEmpty,
           let legacyGroupID = try container.decodeIfPresent(String.self, forKey: .groupID) {
            let legacyName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? ""
            let legacyCode = try container.decodeIfPresent(String.self, forKey: .inviteCode) ?? ""
            joinedGroups = [
                JoinedGroup(groupID: legacyGroupID, groupName: legacyName, inviteCode: legacyCode)
            ]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(petEmoji, forKey: .petEmoji)
        try container.encodeIfPresent(petImageName, forKey: .petImageName)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encode(intervalSeconds, forKey: .intervalSeconds)
        try container.encode(customActionMedia, forKey: .customActionMedia)
        try container.encode(joinedGroups, forKey: .joinedGroups)
        try container.encode(localEventCount, forKey: .localEventCount)
        try container.encode(onboardingComplete, forKey: .onboardingComplete)
        try container.encodeIfPresent(windowOriginX, forKey: .windowOriginX)
        try container.encodeIfPresent(windowOriginY, forKey: .windowOriginY)
        try container.encodeIfPresent(lastReminderTimestamp, forKey: .lastReminderTimestamp)
        // Legacy single-group keys are intentionally NOT written — new format only
    }
}
