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
        if self.userID == userID,
           let task,
           task.closeCode == .invalid {
            return
        }

        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        self.userID = userID
        self.shouldReconnect = true
        self.retryCount = 0
        establishConnection()
    }

    private func establishConnection() {
        guard task == nil, let uid = userID else { return }
        guard let url = URL(string: "\(Constants.wsBaseURL)/ws/\(uid)") else { return }

        let session = URLSession(configuration: .default)
        let newTask = session.webSocketTask(with: url)
        task = newTask
        newTask.resume()
        isConnected = true

        // Start ping loop and receive loop
        startPingLoop(for: newTask)
        Task {
            await receiveLoop(for: newTask)
        }
    }

    private func receiveLoop(for receivingTask: URLSessionWebSocketTask) async {
        do {
            while shouldReconnect && receivingTask.closeCode == .invalid {
                let message = try await receivingTask.receive()
                guard task === receivingTask else { return }
                retryCount = 0
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
            await handleDisconnection(of: receivingTask)
        } catch {
            await handleDisconnection(of: receivingTask)
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

    private func handleDisconnection(of disconnectedTask: URLSessionWebSocketTask) async {
        guard task === disconnectedTask else { return }
        task = nil
        isConnected = false

        guard shouldReconnect else { return }

        let backoff = min(
            pow(2.0, Double(retryCount)),
            Constants.wsReconnectMaxBackoff
        )
        retryCount = min(retryCount + 1, Constants.wsReconnectMaxRetries)

        try? await Task.sleep(for: .seconds(backoff))
        guard shouldReconnect, task == nil else { return }
        establishConnection()
    }

    private func startPingLoop(for pingedTask: URLSessionWebSocketTask) {
        Task {
            while shouldReconnect && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.wsPingInterval))
                guard shouldReconnect, task === pingedTask else { return }
                pingedTask.sendPing { _ in }
            }
        }
    }

    func disconnect() {
        shouldReconnect = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        userID = nil
        retryCount = 0
        isConnected = false
    }
}
