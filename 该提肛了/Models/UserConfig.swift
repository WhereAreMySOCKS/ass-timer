import Foundation

/// A single joined group stored in UserConfig.
struct JoinedGroup: Codable, Identifiable, Equatable {
    var groupID: String
    var groupName: String
    var inviteCode: String
    var id: String { groupID }
}

/// Codable user configuration persisted to UserDefaults.
struct UserConfig: Codable {
    var userID: String?
    var nickname: String?
    var petEmoji: String?
    var petImageName: String?
    var avatarURL: String?
    var intervalSeconds: Int = 2400

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
        try container.encode(joinedGroups, forKey: .joinedGroups)
        try container.encode(localEventCount, forKey: .localEventCount)
        try container.encode(onboardingComplete, forKey: .onboardingComplete)
        try container.encodeIfPresent(windowOriginX, forKey: .windowOriginX)
        try container.encodeIfPresent(windowOriginY, forKey: .windowOriginY)
        try container.encodeIfPresent(lastReminderTimestamp, forKey: .lastReminderTimestamp)
        // Legacy single-group keys are intentionally NOT written — new format only
    }
}
