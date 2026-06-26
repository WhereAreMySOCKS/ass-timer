import SwiftUI

/// Group info view showing all joined groups, their member lists, invite codes, and leave options.
/// Loads data from the backend on appear.
struct GroupInfoView: View {
    @ObservedObject var appState: AppState

    @State private var groups: [GroupInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var groupToLeave: String?

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") { refresh() }
                        .buttonStyle(.bordered)
                }
                Spacer()
            } else if groups.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.3")
                        .font(.title)
                    Text("暂未加入群组")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(groups) { group in
                            groupCard(group)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 300, height: 400)
        .onAppear { refresh() }
        .alert("退出群组？", isPresented: Binding(
            get: { groupToLeave != nil },
            set: { if !$0 { groupToLeave = nil } }
        )) {
            Button("退出", role: .destructive) {
                if let gid = groupToLeave {
                    appState.leaveGroup(groupID: gid)
                    groups.removeAll { $0.group_id == gid }
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

    // MARK: - Group Card

    private func groupCard(_ group: GroupInfo) -> some View {
        VStack(spacing: 12) {
            HStack {
                if !group.name.isEmpty {
                    Text(group.name)
                        .font(.headline)
                } else {
                    Text("未命名群组")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(group.members.count)人")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Invite code
            HStack(spacing: 6) {
                Text("邀请码：")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(Array(group.invite_code), id: \.self) { char in
                    Text(String(char))
                        .font(.caption.monospaced().bold())
                        .frame(width: 24, height: 30)
                        .background(Color.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Spacer()
                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(group.invite_code, forType: .string)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            // Members
            if !group.members.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.members) { member in
                        HStack(spacing: 6) {
                            AvatarImageView(avatarURL: member.avatar_url, size: 20)
                            Text(member.nickname)
                                .font(.caption)
                            if member.user_id == appState.config.userID {
                                Text("我")
                                    .font(.caption2)
                                    .foregroundColor(.accent)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            member.user_id == appState.config.userID
                                ? Color.accent.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            // Leave button
            Button("退出群组", role: .destructive) {
                groupToLeave = group.group_id
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.97))
        )
    }

    // MARK: - Refresh

    private func refresh() {
        guard let uid = appState.config.userID else {
            errorMessage = "未登录"
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
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
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载群组信息失败"
                    isLoading = false
                }
            }
        }
    }
}
