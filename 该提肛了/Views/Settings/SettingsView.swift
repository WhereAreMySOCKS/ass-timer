import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Unified settings panel with tabbed interface.
struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var selectedTab: SettingsTab = .timer

    private enum SettingsTab: Hashable {
        case timer, group, about
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab content — explicit selection binding prevents the NSTabView
            // from resetting to the first tab when observed state changes trigger a re-render.
            TabView(selection: $selectedTab) {
                TimerSettingsTab(appState: appState)
                    .tabItem {
                        Label("提醒", systemImage: "bell")
                    }
                    .tag(SettingsTab.timer)

                GroupSettingsTab(appState: appState)
                    .tabItem {
                        Label("群组", systemImage: "person.3")
                    }
                    .tag(SettingsTab.group)

                AboutTab(appState: appState)
                    .tabItem {
                        Label("关于", systemImage: "info.circle")
                    }
                    .tag(SettingsTab.about)
            }
            .font(.body)
        }
        .frame(width: 340, height: 360)
    }
}

// MARK: - Timer Settings Tab

private struct TimerSettingsTab: View {
    @ObservedObject var appState: AppState

    @State private var intervalSeconds: Int
    @State private var isSaved = false

    init(appState: AppState) {
        self.appState = appState
        _intervalSeconds = State(initialValue: Constants.normalizedIntervalSeconds(appState.config.intervalSeconds))
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            CircularIntervalPicker(seconds: $intervalSeconds)
                .frame(width: 190, height: 190)
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                appState.modifyInterval(intervalSeconds)
                withAnimation {
                    isSaved = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        isSaved = false
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSaved ? "checkmark" : "arrow.down.circle")
                    Text(isSaved ? "已保存" : "保存设置")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Spacer(minLength: 10)
        }
        .padding(18)
        .onChange(of: appState.config.intervalSeconds) { newValue in
            intervalSeconds = Constants.normalizedIntervalSeconds(newValue)
        }
    }
}

// MARK: - Group Settings Tab

private struct GroupSettingsTab: View {
    @ObservedObject var appState: AppState

    @State private var groups: [GroupInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var groupToLeave: GroupInfo?
    @State private var showingJoinSheet = false
    @State private var showingCreateSheet = false
    @State private var inviteCode = ""
    @State private var newGroupName = ""
    @State private var isJoiningGroup = false
    @State private var isCreatingGroup = false
    @State private var joinErrorMessage: String?
    @State private var createErrorMessage: String?
    @State private var expandedGroupIDs: Set<String> = []

    private var normalizedInviteCode: String {
        inviteCode.sanitized.uppercased()
    }

    private var inviteCodeReady: Bool {
        normalizedInviteCode.count == Constants.inviteCodeLength
    }

    private var normalizedNewGroupName: String {
        newGroupName.sanitized
    }

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载中…")
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") { refresh() }
                        .buttonStyle(.bordered)
                    Spacer()
                }
            } else if !groups.isEmpty {
                groupsContent
            } else {
                noGroupView
            }
        }
        .onAppear { refresh() }
        .sheet(isPresented: $showingJoinSheet) {
            joinGroupSheet
        }
        .sheet(isPresented: $showingCreateSheet) {
            createGroupSheet
        }
        .alert("退出群组？", isPresented: Binding(
            get: { groupToLeave != nil },
            set: { if !$0 { groupToLeave = nil } }
        )) {
            Button("退出", role: .destructive) {
                if let group = groupToLeave {
                    appState.leaveGroup(groupID: group.group_id)
                    groups.removeAll { $0.group_id == group.group_id }
                    expandedGroupIDs.remove(group.group_id)
                    groupToLeave = nil
                }
            }
            Button("取消", role: .cancel) {
                groupToLeave = nil
            }
        } message: {
            Text("退出后需要邀请码才能重新加入")
        }
    }

    private var groupsContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("已加入 \(groups.count) 个群组")
                        .font(.headline)
                    Spacer()
                    Button {
                        showCreateSheet()
                    } label: {
                        Label("新建", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        showJoinSheet()
                    } label: {
                        Label("加入", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ForEach(groups) { group in
                    groupCard(group)
                }
            }
            .padding(16)
        }
    }

    private func groupCard(_ info: GroupInfo) -> some View {
        let isExpanded = expandedGroupIDs.contains(info.group_id)

        return VStack(spacing: 12) {
            Button {
                toggleGroupExpansion(info.group_id)
            } label: {
                HStack {
                    Text(info.name.isEmpty ? "未命名群组" : info.name)
                        .font(.headline)
                    Spacer()
                    Text("\(info.members.count)人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    Text("邀请码")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 5) {
                        ForEach(Array(info.invite_code), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .frame(width: 28, height: 34)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(info.invite_code, forType: .string)
                    } label: {
                        Label("复制邀请码", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if !info.members.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("成员")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(spacing: 4) {
                            ForEach(info.members) { member in
                                HStack(spacing: 8) {
                                    AvatarImageView(avatarURL: member.avatar_url, size: 24)
                                    Text(member.nickname)
                                        .font(.subheadline)
                                    Spacer()
                                    if member.user_id == appState.config.userID {
                                        Text("我")
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Button("退出群组", role: .destructive) {
                    groupToLeave = info
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var noGroupView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.3")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("未加入群组")
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Button {
                    showCreateSheet()
                } label: {
                    Label("新建群组", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    showJoinSheet()
                } label: {
                    Label("加入群组", systemImage: "person.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer()
        }
    }

    private var joinGroupSheet: some View {
        VStack(spacing: 14) {
            Text("加入群组")
                .font(.headline)

            TextField("ABC123", text: $inviteCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 180)
                .onChange(of: inviteCode) { _ in
                    inviteCode = String(normalizedInviteCode.prefix(Constants.inviteCodeLength))
                    joinErrorMessage = nil
                }

            if let joinErrorMessage {
                Text(joinErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("取消") {
                    showingJoinSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task { await joinGroupFromSheet() }
                } label: {
                    if isJoiningGroup {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("加入")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!inviteCodeReady || isJoiningGroup)
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private var createGroupSheet: some View {
        VStack(spacing: 14) {
            Text("新建群组")
                .font(.headline)

            TextField("群组名称", text: $newGroupName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .frame(width: 200)
                .onChange(of: newGroupName) { _ in
                    createErrorMessage = nil
                }

            if let createErrorMessage {
                Text(createErrorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button("取消") {
                    showingCreateSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task { await createGroupFromSheet() }
                } label: {
                    if isCreatingGroup {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("创建")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedNewGroupName.isEmpty || isCreatingGroup)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    private func refresh() {
        Task { await refreshAsync() }
    }

    private func refreshAsync() async {
        guard let uid = appState.config.userID else {
            errorMessage = "未登录"
            isLoading = false
            groups = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await appState.apiClient.getUserGroups(userID: uid)
            groups = fetched.map { GroupInfo(
                group_id: $0.group_id,
                name: $0.name,
                invite_code: $0.invite_code,
                members: $0.members,
                created_at: $0.created_at
            ) }
        } catch {
            errorMessage = "加载群组信息失败"
        }
    }

    private func showJoinSheet() {
        inviteCode = ""
        joinErrorMessage = nil
        showingJoinSheet = true
    }

    private func showCreateSheet() {
        newGroupName = ""
        createErrorMessage = nil
        showingCreateSheet = true
    }

    private func joinGroupFromSheet() async {
        guard !isJoiningGroup else { return }
        guard let userID = appState.config.userID else {
            joinErrorMessage = "未登录"
            return
        }
        guard inviteCodeReady else {
            joinErrorMessage = "请输入6位邀请码"
            return
        }

        isJoiningGroup = true
        joinErrorMessage = nil
        defer { isJoiningGroup = false }

        do {
            let resp = try await appState.apiClient.joinGroup(
                userID: userID,
                code: normalizedInviteCode
            )
            appState.addGroup(
                groupID: resp.group_id,
                groupName: resp.name,
                inviteCode: resp.invite_code
            )
            expandedGroupIDs.insert(resp.group_id)
            showingJoinSheet = false
            inviteCode = ""
            await refreshAsync()
        } catch {
            joinErrorMessage = "邀请码无效，或你已经在这个群组里"
        }
    }

    private func createGroupFromSheet() async {
        guard !isCreatingGroup else { return }
        guard let userID = appState.config.userID else {
            createErrorMessage = "未登录"
            return
        }
        guard !normalizedNewGroupName.isEmpty else {
            createErrorMessage = "请输入群组名称"
            return
        }

        isCreatingGroup = true
        createErrorMessage = nil
        defer { isCreatingGroup = false }

        do {
            let resp = try await appState.apiClient.createGroup(
                creatorID: userID,
                name: normalizedNewGroupName
            )
            appState.addGroup(
                groupID: resp.group_id,
                groupName: resp.name,
                inviteCode: resp.invite_code
            )
            expandedGroupIDs.insert(resp.group_id)
            showingCreateSheet = false
            newGroupName = ""
            await refreshAsync()
        } catch {
            createErrorMessage = "创建群组失败"
        }
    }

    private func toggleGroupExpansion(_ groupID: String) {
        if expandedGroupIDs.contains(groupID) {
            expandedGroupIDs.remove(groupID)
        } else {
            expandedGroupIDs.insert(groupID)
        }
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var updateService: UpdateService

    @State private var showClearConfirmation = false
    @State private var isClearingLocalData = false
    @State private var isUploadingAvatar = false
    @State private var avatarStatusMessage: String?
    @State private var avatarUploadFailed = false

    init(appState: AppState) {
        self.appState = appState
        _updateService = ObservedObject(wrappedValue: appState.updateService)
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            VStack(spacing: 4) {
                Text("该提肛了")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("v\(updateService.currentVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                AvatarImageView(avatarURL: appState.config.avatarURL ?? "", size: 58)
                    .id(appState.config.avatarURL)
                    .accessibilityLabel("当前头像")

                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.config.nickname ?? "未设置昵称")
                        .font(.headline)
                        .lineLimit(1)

                    Button(action: chooseAvatar) {
                        HStack(spacing: 6) {
                            if isUploadingAvatar {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "photo.badge.plus")
                            }
                            Text(isUploadingAvatar ? "上传中…" : "更新头像")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isUploadingAvatar || appState.config.userID == nil)
                }

                Spacer()
            }
            .padding(12)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let avatarStatusMessage {
                Label(
                    avatarStatusMessage,
                    systemImage: avatarUploadFailed
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundColor(avatarUploadFailed ? .red : .green)
            }

            updateStatusView

            Button {
                Task {
                    await updateService.checkForUpdate()
                }
            } label: {
                Label(
                    updateService.isChecking ? "检查中…" : "检查更新",
                    systemImage: "arrow.clockwise"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(updateService.isChecking)

            Divider()

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label(isClearingLocalData ? "清除中…" : "清除本地数据", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(isClearingLocalData)

            Spacer()
        }
        .padding(16)
        .alert("清除本地数据？", isPresented: $showClearConfirmation) {
            Button("清除", role: .destructive) {
                isClearingLocalData = true
                Task {
                    await appState.clearLocalData()
                    isClearingLocalData = false
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会删除当前后端用户，并清除昵称、群组、提醒进度、计数、聊天记录、头像缓存和初始化状态。")
        }
    }

    private func chooseAvatar() {
        guard !isUploadingAvatar, appState.config.userID != nil else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.message = "选择新头像"
        panel.prompt = "上传"

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                await uploadAvatar(url)
            }
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    private func uploadAvatar(_ fileURL: URL) async {
        guard let userID = appState.config.userID else { return }

        isUploadingAvatar = true
        avatarStatusMessage = nil
        avatarUploadFailed = false
        defer { isUploadingAvatar = false }

        do {
            let response = try await appState.apiClient.updateUser(
                userID: userID,
                nickname: nil,
                avatarURL: fileURL
            )
            appState.config.nickname = response.nickname
            appState.config.petEmoji = response.pet_emoji
            appState.config.avatarURL = response.avatar_url
            appState.saveConfig()
            avatarStatusMessage = "头像已更新"
        } catch APIError.invalidFile(let message) {
            avatarUploadFailed = true
            avatarStatusMessage = message
        } catch APIError.serverError(let code, _) where code == 422 {
            avatarUploadFailed = true
            avatarStatusMessage = "请选择 10MB 以内的 PNG、JPG、GIF 或 WebP 图片"
        } catch {
            avatarUploadFailed = true
            avatarStatusMessage = "头像上传失败，请稍后重试"
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateService.status {
        case .unknown:
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("尚未检查更新")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("检查更新中…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已是最新版本")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .updateAvailable(let version, let notes, _, let forceRequired):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.orange)
                    Text("发现新版本 v\(version)")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                if !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    updateService.openDownloadPage()
                } label: {
                    Label("下载更新", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if forceRequired {
                    Text("此版本为强制更新")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

}
