import SwiftUI

/// Leaderboard view showing the top N members of a group, sorted by Kegel count.
/// Supports switching between multiple joined groups via a top menu.
struct LeaderboardView: View {
    @ObservedObject var appState: AppState

    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var refreshTimer: Timer?
    @State private var groups: [GroupInfo] = []
    @State private var selectedGroupID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("🏆 排行榜")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !groups.isEmpty {
                    Menu {
                        ForEach(groups) { group in
                            Button(action: { selectGroup(group) }) {
                                HStack {
                                    Text(group.name.isEmpty ? "未命名群组" : group.name)
                                    if group.group_id == selectedGroupID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(groupNameForID(selectedGroupID))
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accent.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            // Content
            if isLoading && entries.isEmpty {
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
            } else if entries.isEmpty {
                Spacer()
                Text("暂无数据")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(entries) { entry in
                        leaderboardRow(entry)
                    }
                }
                .listStyle(.plain)
            }

            // Footer
            if !entries.isEmpty {
                Divider()
                HStack {
                    Text("我的总提肛：\(appState.config.localEventCount)次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320, height: 420)
        .onAppear {
            loadGroups()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    @ViewBuilder
    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        let isSelf = entry.user_id == appState.config.userID

        HStack(spacing: 12) {
            // Rank
            Text(rankEmoji(entry.rank) + " \(entry.rank)")
                .font(.headline)
                .frame(width: 50, alignment: .leading)

            AvatarImageView(avatarURL: entry.avatar_url, size: 28)
            Text(entry.nickname)
                .font(.body)
                .fontWeight(isSelf ? .bold : .regular)

            Spacer()

            // Count
            Text("\(entry.count)次")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelf ? Color.selfHighlight : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    private func groupNameForID(_ id: String?) -> String {
        guard let id else { return "选择群组" }
        return groups.first(where: { $0.group_id == id })?.name ?? "选择群组"
    }

    private func loadGroups() {
        guard let uid = appState.config.userID else {
            errorMessage = "未登录"
            isLoading = false
            return
        }
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
                    if selectedGroupID == nil, let first = groups.first {
                        selectGroup(first)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载群组失败"
                    isLoading = false
                }
            }
        }
    }

    private func selectGroup(_ group: GroupInfo) {
        selectedGroupID = group.group_id
        refresh()
        // Start auto-refresh
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.leaderboardRefreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await refreshAsync()
            }
        }
    }

    private func refresh() {
        Task { await refreshAsync() }
    }

    private func refreshAsync() async {
        guard let gid = selectedGroupID else {
            if groups.isEmpty {
                errorMessage = "未加入群组"
            }
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let resp = try await appState.apiClient.getLeaderboard(groupID: gid)
            entries = resp.entries
            isLoading = false
        } catch {
            errorMessage = "加载排行榜失败"
            isLoading = false
        }
    }
}
