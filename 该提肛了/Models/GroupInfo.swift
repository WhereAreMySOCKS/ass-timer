import Foundation

/// Represents a group and its members for the client.
struct GroupInfo: Codable, Identifiable {
    let group_id: String
    let name: String
    let invite_code: String
    let members: [MemberInfo]
    let created_at: String?

    var id: String { group_id }

    var memberCount: Int { members.count }
}

struct MemberInfo: Codable, Identifiable {
    let user_id: String
    let nickname: String
    let pet_emoji: String
    let avatar_url: String

    var id: String { user_id }
}
