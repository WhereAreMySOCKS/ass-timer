import Foundation

/// Actor-based WebSocket client using URLSessionWebSocketTask.
/// Handles reconnection with exponential backoff.
actor WebSocketClient {
    private var task: URLSessionWebSocketTask?
    private var userID: String?
    private var retryCount = 0
    private var isConnected = false
    private var shouldReconnect = true
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func connect(userID: String) {
        self.userID = userID
        self.shouldReconnect = true
        establishConnection()
    }

    private func establishConnection() {
        guard let uid = userID else { return }
        guard let url = URL(string: "\(Constants.wsBaseURL)/ws/\(uid)") else { return }

        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task?.resume()
        retryCount = 0
        isConnected = true

        // Start ping loop and receive loop
        startPingLoop()
        Task {
            await receiveLoop()
        }
    }

    private func receiveLoop() async {
        guard let task else { return }

        do {
            while shouldReconnect && task.closeCode == .invalid {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            await handleDisconnection()
        }
    }

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "group_event":
            guard let dataDict = json["data"] as? [String: Any],
                  let nickname = dataDict["nickname"] as? String,
                  let petEmoji = dataDict["pet_emoji"] as? String else { return }

            let avatarURL = dataDict["avatar_url"] as? String

            let state = self.appState
            await MainActor.run {
                state?.addBubble(
                    .groupEvent,
                    senderNickname: nickname,
                    senderPetEmoji: petEmoji,
                    senderAvatarURL: avatarURL
                )
            }

        case "chat_message":
            guard let dataDict = json["data"] as? [String: Any],
                  let groupID = json["group_id"] as? String else { return }

            // Decode chat message from data dict
            let state = self.appState
            await MainActor.run {
                // Convert dict to ChatMessageResponse
                if let msgData = try? JSONSerialization.data(withJSONObject: dataDict),
                   let msg = try? JSONDecoder().decode(ChatMessageResponse.self, from: msgData) {
                    state?.onChatMessageReceived(groupID: groupID, message: msg)
                }
            }

        default:
            break
        }
    }

    private func handleDisconnection() async {
        isConnected = false

        guard shouldReconnect && retryCount < Constants.wsReconnectMaxRetries else {
            return
        }

        let backoff = min(
            pow(2.0, Double(retryCount)),
            Constants.wsReconnectMaxBackoff
        )
        retryCount += 1

        try? await Task.sleep(for: .seconds(backoff))
        establishConnection()
    }

    private func startPingLoop() {
        Task {
            while shouldReconnect && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.wsPingInterval))
                task?.sendPing { _ in }
            }
        }
    }

    func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }
}
