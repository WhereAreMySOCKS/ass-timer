import SwiftUI

/// Full chat window with left group list and right message area.
struct ChatView: View {
    @ObservedObject var appState: AppState

    @State private var groups: [GroupInfo] = []
    @State private var selectedGroupID: String?
    @State private var messages: [ChatMessageResponse] = []
    @State private var inputText: String = ""
    @State private var isLoadingGroups = false
    @State private var isLoadingHistory = false
    @State private var hasMore = false
    @State private var groupError: String?
    @State private var inviteCodeToShow: String?
    @State private var inviteCodeCopied = false
    @State private var requestedGroupID: String?

    init(appState: AppState, initialGroupID: String? = nil) {
        self.appState = appState
        _requestedGroupID = State(initialValue: initialGroupID)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar: group list
            groupListSidebar

            Divider()

            // Right: messages
            if let selectedID = selectedGroupID {
                messageArea(groupID: selectedID)
            } else {
                emptyState
            }
        }
        .frame(minWidth: 560, minHeight: 380)
        .onAppear(perform: loadGroups)
        .onReceive(NotificationCenter.default.publisher(for: .chatMessageReceived)) { notif in
            handleIncomingMessage(notif)
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectChatGroup)) { notification in
            guard let groupID = notification.userInfo?["groupID"] as? String else { return }
            requestedGroupID = groupID
            selectRequestedGroupIfAvailable()
        }
        .alert("群组邀请码", isPresented: Binding(
            get: { inviteCodeToShow != nil },
            set: {
                if !$0 {
                    inviteCodeToShow = nil
                    inviteCodeCopied = false
                }
            }
        )) {
            Button(inviteCodeCopied ? "已复制" : "复制") {
                if let inviteCodeToShow {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(inviteCodeToShow, forType: .string)
                    inviteCodeCopied = true
                }
            }
            Button("关闭", role: .cancel) {
                inviteCodeToShow = nil
                inviteCodeCopied = false
            }
        } message: {
            Text(inviteCodeToShow ?? "")
        }
    }

    // MARK: - Group List Sidebar

    var groupListSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoadingGroups {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                Spacer()
            } else if let error = groupError {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.title2)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") { loadGroups() }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.title)
                    Text("暂未加入群组")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // SwiftUI's macOS List keeps system row separators on some OS
                // versions even with the plain style. A simple scroll stack gives
                // this sidebar an identical, separator-free appearance everywhere.
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(displayedGroups) { group in
                            GroupListRow(
                                group: group,
                                isSelected: group.group_id == selectedGroupID,
                                unreadCount: appState.chatUnreadCounts[group.group_id] ?? 0,
                                onSelect: {
                                    selectGroup(group)
                                }
                            )
                        }
                    }
                    .padding(4)
                }
            }
        }
        .frame(width: 170)
        .background(Color(white: 0.97))
    }

    private var displayedGroups: [GroupInfo] {
        let unreadOrder = Dictionary(
            uniqueKeysWithValues: appState.chatUnreadGroupOrder.enumerated().map { ($1, $0) }
        )
        let originalOrder = Dictionary(
            uniqueKeysWithValues: groups.enumerated().map { ($1.group_id, $0) }
        )

        return groups.sorted { lhs, rhs in
            let lhsUnreadIndex = unreadOrder[lhs.group_id] ?? Int.max
            let rhsUnreadIndex = unreadOrder[rhs.group_id] ?? Int.max
            if lhsUnreadIndex != rhsUnreadIndex {
                return lhsUnreadIndex < rhsUnreadIndex
            }
            return (originalOrder[lhs.group_id] ?? 0) < (originalOrder[rhs.group_id] ?? 0)
        }
    }

    // MARK: - Message Area

    func messageArea(groupID: String) -> some View {
        VStack(spacing: 0) {
            // Group name header
            if let group = groups.first(where: { $0.group_id == groupID }) {
                HStack {
                    Text(group.name.isEmpty ? "群聊" : group.name)
                        .font(.headline)
                    Text("(\(group.memberCount)人)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        inviteCodeToShow = group.invite_code
                        inviteCodeCopied = false
                    } label: {
                        Label("邀请码", systemImage: "number")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
            }

            // Messages
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // Load more button
                        if hasMore {
                            HStack {
                                Spacer()
                                if isLoadingHistory {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Button("加载更早的消息") {
                                        loadMoreHistory()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.borderless)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }

                        ForEach(messages) { msg in
                            ChatMessageRow(
                                message: msg,
                                isSelf: msg.user_id == appState.config.userID
                            )
                            .id(msg.message_id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.message_id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = messages.last {
                        scrollProxy.scrollTo(last.message_id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input bar
            ChatInputBar(
                text: $inputText,
                onSend: sendMessage
            )
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "message")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("选择一个群组开始聊天")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadGroups() {
        guard let uid = appState.config.userID else { return }
        let cachedGroups = appState.config.joinedGroups.map { joined in
            GroupInfo(
                group_id: joined.groupID,
                name: joined.groupName,
                invite_code: joined.inviteCode,
                members: [],
                created_at: nil
            )
        }

        if !cachedGroups.isEmpty {
            groups = cachedGroups
            isLoadingGroups = false
            groupError = nil
            selectRequestedGroupIfAvailable()
        } else {
            isLoadingGroups = true
        }
        groupError = nil
        Task {
            do {
                let fetched = try await appState.apiClient.getUserGroups(userID: uid)
                await MainActor.run {
                    groups = fetched.map { GroupInfo(
                        group_id: $0.group_id,
                        name: $0.name,
                        invite_code: $0.invite_code,
                        members: $0.members,
                        created_at: $0.created_at
                    )}
                    isLoadingGroups = false
                    selectRequestedGroupIfAvailable()
                }
            } catch {
                await MainActor.run {
                    if groups.isEmpty {
                        groupError = "加载群组失败"
                    }
                    isLoadingGroups = false
                }
            }
        }
    }

    private func selectGroup(_ group: GroupInfo, markAsRead: Bool = true) {
        selectedGroupID = group.group_id
        if markAsRead {
            appState.markChatGroupRead(group.group_id)
        }
        messages = LocalCacheManager.shared.loadMessages(groupID: group.group_id)
        hasMore = false
        loadHistory()
    }

    private func selectRequestedGroupIfAvailable() {
        if let requestedGroupID,
           let requestedGroup = groups.first(where: { $0.group_id == requestedGroupID }) {
            self.requestedGroupID = nil
            selectGroup(requestedGroup)
            return
        }

        // Initial layout selection is not a deliberate read action. This keeps
        // unread badges visible until the user picks that conversation.
        if selectedGroupID == nil, let first = groups.first {
            selectGroup(first, markAsRead: false)
        }
    }

    private func loadHistory(beforeID: String? = nil) {
        guard let gid = selectedGroupID else { return }
        isLoadingHistory = true
        Task {
            do {
                let resp = try await appState.apiClient.getChatHistory(
                    groupID: gid, limit: 50, beforeID: beforeID
                )
                await MainActor.run {
                    if beforeID == nil {
                        messages = mergedMessages(messages + resp.messages)
                    } else {
                        messages = mergedMessages(resp.messages + messages)
                    }
                    LocalCacheManager.shared.saveMessages(messages, groupID: gid)
                    hasMore = resp.has_more
                    isLoadingHistory = false
                }
            } catch {
                await MainActor.run {
                    isLoadingHistory = false
                }
            }
        }
    }

    private func loadMoreHistory() {
        guard let oldest = messages.first else { return }
        loadHistory(beforeID: oldest.message_id)
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let gid = selectedGroupID, let uid = appState.config.userID else { return }

        inputText = ""
        Task {
            do {
                let msg = try await appState.apiClient.sendChatMessage(
                    groupID: gid, userID: uid, content: trimmed
                )
                await MainActor.run {
                    messages = mergedMessages(messages + [msg])
                    LocalCacheManager.shared.saveMessages(messages, groupID: gid)
                }
            } catch {
                // Re-show the text on failure
                await MainActor.run {
                    inputText = trimmed
                }
            }
        }
    }

    private func handleIncomingMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let groupID = userInfo["groupID"] as? String,
              let message = userInfo["message"] as? ChatMessageResponse else { return }

        if groupID == selectedGroupID {
            messages = mergedMessages(messages + [message])
            appState.markChatGroupRead(groupID)
        }
    }

    private func mergedMessages(_ newMessages: [ChatMessageResponse]) -> [ChatMessageResponse] {
        var byID: [String: ChatMessageResponse] = [:]
        for message in newMessages {
            byID[message.message_id] = message
        }
        return byID.values.sorted { lhs, rhs in
            lhs.created_at < rhs.created_at
        }
    }
}
