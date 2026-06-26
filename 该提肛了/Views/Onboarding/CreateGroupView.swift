import SwiftUI

/// View for creating a new group. Displays invite code + group info after creation.
struct CreateGroupView: View {
    @ObservedObject var appState: AppState
    @Binding var groupName: String
    var onCreate: (String, String, String) async -> Bool
    var onBack: () -> Void
    var onFinish: () -> Void

    @State private var createdGroupID: String?
    @State private var createdName: String?
    @State private var createdInviteCode: String?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var groupInfo: GroupInfo?
    @State private var isLoadingInfo = false

    private var sanitizedGroupName: String {
        groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 24) {
            if let code = createdInviteCode {
                successView(inviteCode: code)
            } else {
                creationForm
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
    }

    // MARK: - Creation Form

    private var creationForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("创建群组")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.charcoalText)

                Text("创建新群组并分享邀请码给好友")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("群组名称（必填）", text: $groupName)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.claySurface)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 1, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1.2)
                )
                .frame(maxWidth: 260)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.coral)
            }

            Button {
                Task {
                    guard !sanitizedGroupName.isEmpty else {
                        errorMessage = "请输入群组名称"
                        return
                    }

                    isCreating = true
                    errorMessage = nil
                    let success = await onCreate(
                        appState.config.userID ?? "",
                        sanitizedGroupName,
                        ""
                    )
                    isCreating = false
                    if success {
                        // Read from appState after successful creation
                        createdInviteCode = appState.config.joinedGroups.last?.inviteCode
                        createdGroupID = appState.config.joinedGroups.last?.groupID
                        createdName = appState.config.joinedGroups.last?.groupName
                    } else {
                        errorMessage = "创建群组失败"
                    }
                }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text("创建群组")
                }
            }
            .buttonStyle(ClayPrimaryButtonStyle())
            .disabled(isCreating || sanitizedGroupName.isEmpty)

            Button("返回") { onBack() }
                .buttonStyle(ClaySecondaryButtonStyle())
        }
    }

    // MARK: - Success View

    private func successView(inviteCode: String) -> some View {
        VStack(spacing: 20) {
            // Success header
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accent)
                Text("群组已创建！")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.charcoalText)
                Text("把这个邀请码分享给好友：")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Invite code — clay raised cards
            HStack(spacing: 10) {
                ForEach(Array(inviteCode), id: \.self) { char in
                    Text(String(char))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .frame(width: 42, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.claySurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.9), Color.clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 2, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accent.opacity(0.3), lineWidth: 1.2)
                        )
                }
            }

            // Copy button
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(inviteCode, forType: .string)
            } label: {
                Label("复制邀请码", systemImage: "doc.on.doc")
            }
            .buttonStyle(ClaySecondaryButtonStyle())

            Divider()
                .padding(.vertical, 4)

            // Group info section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.accent)
                    Text("群组信息")
                        .font(.headline)
                        .foregroundColor(.charcoalText)
                    Spacer()
                }

                if isLoadingInfo {
                    HStack {
                        Spacer()
                        ProgressView("加载中…")
                            .scaleEffect(0.8)
                        Spacer()
                    }
                } else if let info = groupInfo {
                    VStack(spacing: 8) {
                        // Group name
                        if !info.name.isEmpty {
                            HStack {
                                Image(systemName: "tag.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(info.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.charcoalText)
                                Spacer()
                            }
                        }

                        // Member count
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(info.members.count) 位成员")
                                .font(.subheadline)
                                .foregroundColor(.charcoalText)
                            Spacer()
                        }

                        // First few members
                        if !info.members.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(info.members.prefix(5)) { member in
                                    HStack(spacing: 8) {
                                        Image(systemName: "hare.fill")
                                            .font(.caption)
                                            .foregroundColor(.accent)
                                        Text(member.nickname)
                                            .font(.subheadline)
                                        Spacer()
                                        if member.user_id == appState.config.userID {
                                            Text("我")
                                                .font(.caption2)
                                                .foregroundColor(.accent)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.accent.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                if info.members.count > 5 {
                                    Text("...及其他 \(info.members.count - 5) 位成员")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.clayBackground)
                    )
                } else {
                    Button("加载群组信息") {
                        Task { await loadGroupInfo() }
                    }
                    .buttonStyle(ClaySubtleButtonStyle())
                }
            }

            Spacer().frame(height: 8)

            // Finish button
            Button("完成设置") {
                onFinish()
            }
            .buttonStyle(ClayPrimaryButtonStyle())
        }
        .onAppear {
            Task { await loadGroupInfo() }
        }
    }

    // MARK: - Helpers

    private func loadGroupInfo() async {
        guard let gid = createdGroupID ?? appState.config.primaryGroupID else { return }
        isLoadingInfo = true
        do {
            let resp = try await appState.apiClient.getGroupInfo(groupID: gid)
            groupInfo = GroupInfo(
                group_id: resp.group_id,
                name: resp.name,
                invite_code: resp.invite_code,
                members: resp.members,
                created_at: resp.created_at
            )
        } catch {
            // Silently fail — group info is optional
        }
        isLoadingInfo = false
    }
}
