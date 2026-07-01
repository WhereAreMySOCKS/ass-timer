import Foundation

// MARK: - API Types (mirrored from server schemas)

struct UserCreateResponse: Codable {
    let user_id: String
    let nickname: String
    let pet_emoji: String
    let avatar_url: String
    let created_at: String?
}

struct GroupCreateResponse: Codable {
    let group_id: String
    let name: String
    let invite_code: String
    let member_count: Int
}

struct GroupJoinResponse: Codable {
    let group_id: String
    let name: String
    let invite_code: String
    let member_count: Int
}

struct GroupInfoResponse: Codable {
    let group_id: String
    let name: String
    let invite_code: String
    let members: [MemberInfo]
    let created_at: String?
}

struct EventLogResponse: Codable {
    let event_id: Int
    let recorded_at: String?
    let events_logged: Int?
}

struct LeaderboardEntry: Codable, Identifiable {
    let rank: Int
    let user_id: String
    let nickname: String
    let pet_emoji: String
    let avatar_url: String
    let count: Int

    var id: String { user_id }
}

struct LeaderboardResponse: Codable {
    let group_id: String
    let entries: [LeaderboardEntry]
    let total_members: Int
}

// MARK: - New API Types for multi-group, chat, user updates

struct UserUpdateResponse: Codable {
    let user_id: String
    let nickname: String
    let pet_emoji: String
    let avatar_url: String
    let created_at: String?
}

struct UserGroupsResponse: Codable {
    let groups: [GroupInfoResponse]
}

struct ChatMessageResponse: Codable, Identifiable {
    let message_id: String
    let group_id: String
    let user_id: String
    let nickname: String
    let pet_emoji: String
    let avatar_url: String
    let content: String
    let created_at: String

    var id: String { message_id }
}

struct ChatHistoryResponse: Codable {
    let messages: [ChatMessageResponse]
    let has_more: Bool
}

// MARK: - API Client

enum APIError: Error, LocalizedError {
    case networkError(String)
    case serverError(Int, String)
    case decodingError
    case invalidFile(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network error: \(msg)"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError: return "Failed to decode response"
        case .invalidFile(let msg): return msg
        }
    }
}

/// Async HTTP client for the Ass-Timer API.
actor APIClient {
    private let session: URLSession
    private let baseURL: String

    init(baseURL: String) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - User

    func createUser(nickname: String, avatarURL: URL) async throws -> UserCreateResponse {
        return try await postMultipart(
            "/user/create",
            fields: ["nickname": nickname],
            fileField: "avatar",
            fileURL: avatarURL
        )
    }

    func deleteUser(userID: String) async throws {
        guard let url = URL(string: "\(baseURL)/user/\(userID)") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.networkError("Delete failed")
        }
    }

    // MARK: - Group

    func createGroup(creatorID: String, name: String) async throws -> GroupCreateResponse {
        let body = ["creator_user_id": creatorID, "group_name": name]
        print("[APIClient] 🚀 POST /group/create body=\(body)")
        let response: GroupCreateResponse = try await post("/group/create", body: body)
        print("[APIClient] ✅ POST /group/create response: groupID=\(response.group_id), inviteCode=\(response.invite_code)")
        return response
    }

    func joinGroup(userID: String, code: String) async throws -> GroupJoinResponse {
        let body = ["user_id": userID, "invite_code": code]
        print("[APIClient] 🚀 POST /group/join body=\(body)")
        let response: GroupJoinResponse = try await post("/group/join", body: body)
        print("[APIClient] ✅ POST /group/join response: groupID=\(response.group_id), inviteCode=\(response.invite_code)")
        return response
    }

    func leaveGroup(userID: String, groupID: String) async throws {
        let body = ["user_id": userID, "group_id": groupID]
        _ = try await post("/group/leave", body: body) as GenericResponse
    }

    func getGroupInfo(groupID: String) async throws -> GroupInfoResponse {
        return try await get("/group/\(groupID)/info")
    }

    func getLeaderboard(groupID: String) async throws -> LeaderboardResponse {
        return try await get("/group/\(groupID)/rank")
    }

    // MARK: - User Update

    /// Update user profile. If avatarURL is provided, uses multipart; otherwise form-encoded.
    func updateUser(userID: String, nickname: String?, avatarURL: URL?) async throws -> UserUpdateResponse {
        if let avatarURL {
            var fields: [String: String] = [:]
            if let nickname {
                fields["nickname"] = nickname
            }
            return try await postMultipart(
                "/user/\(userID)",
                fields: fields,
                fileField: "avatar",
                fileURL: avatarURL,
                httpMethod: "PATCH"
            )
        } else if let nickname {
            return try await postForm("/user/\(userID)", fields: ["nickname": nickname])
        } else {
            throw APIError.networkError("Nothing to update")
        }
    }

    func getUserGroups(userID: String) async throws -> [GroupInfoResponse] {
        let response: UserGroupsResponse = try await get("/user/\(userID)/groups")
        return response.groups
    }

    // MARK: - Chat

    func getChatHistory(groupID: String, limit: Int = 50, beforeID: String? = nil) async throws -> ChatHistoryResponse {
        var path = "/group/\(groupID)/messages?limit=\(limit)"
        if let bid = beforeID {
            path += "&before_id=\(bid)"
        }
        return try await get(path)
    }

    func sendChatMessage(groupID: String, userID: String, content: String) async throws -> ChatMessageResponse {
        let body = ["user_id": userID, "content": content]
        return try await post("/group/\(groupID)/messages", body: body)
    }

    // MARK: - Event

    func logEvent(userID: String, groupIDs: [String]?) async throws -> EventLogResponse {
        var body: [String: Any] = ["user_id": userID]
        if let gids = groupIDs, !gids.isEmpty {
            body["group_ids"] = gids
        }
        // Use custom JSON encoding for mixed types
        guard let url = URL(string: "\(baseURL)/event") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    // MARK: - HTTP Helpers

    private func postForm<T: Decodable>(_ path: String, fields: [String: String]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.networkError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            print("[APIClient] ❌ Invalid URL: \(baseURL)\(path)")
            throw APIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        print("[APIClient] 📡 Request: \(request.httpMethod) \(url.absoluteString)")
        print("[APIClient] 📦 Body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("[APIClient] ❌ Invalid response type")
            throw APIError.networkError("Invalid response")
        }
        
        let responseBody = String(data: data, encoding: .utf8) ?? "nil"
        print("[APIClient] 📥 Response: \(httpResponse.statusCode) - \(responseBody)")
        
        return try handleResponse(data: data, response: response)
    }

    private func postMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String],
        fileField: String,
        fileURL: URL,
        httpMethod: String = "POST"
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.networkError("Invalid URL")
        }

        let fileData: Data
        let didAccessSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScopedResource {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw APIError.invalidFile("无法读取头像文件")
        }

        guard !fileData.isEmpty else {
            throw APIError.invalidFile("头像文件为空")
        }

        let fileName = fileURL.lastPathComponent.isEmpty ? "avatar.png" : fileURL.lastPathComponent
        let mimeType = Self.mimeType(for: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func handleResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[APIClient] ❌ Server error \(httpResponse.statusCode): \(msg)")
            throw APIError.serverError(httpResponse.statusCode, msg)
        }

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            print("[APIClient] ✅ Decoded response successfully")
            return decoded
        } catch {
            print("[APIClient] ❌ Decoding error: \(error)")
            print("[APIClient] ❌ Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError
        }
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        default:
            return "image/png"
        }
    }
}

/// Fallback generic response for endpoints that return simple JSON.
private struct GenericResponse: Decodable {}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
