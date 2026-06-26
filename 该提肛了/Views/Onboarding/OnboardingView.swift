import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    var onComplete: () -> Void

    private enum Step: Int, CaseIterable {
        case profile
        case timing
        case group
        case createGroup
        case joinGroup
        case groupCreated
    }

    private struct SidebarStep: Identifiable {
        let id: Step
        let title: String
        let symbolName: String
    }

    private let sidebarSteps: [SidebarStep] = [
        .init(id: .profile, title: "资料", symbolName: "person.crop.circle"),
        .init(id: .timing, title: "间隔", symbolName: "timer"),
        .init(id: .group, title: "群组", symbolName: "person.2"),
    ]

    @State private var step: Step = .profile
    @State private var nickname = ""
    @State private var selectedAvatarURL: URL?
    @State private var selectedAvatarImage: NSImage?
    @State private var intervalSeconds = Constants.defaultIntervalSeconds
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var createdInviteCode: String?
    @State private var createdGroupName: String?
    @State private var isCreatingUser = false
    @State private var isCreatingGroup = false
    @State private var isJoiningGroup = false
    @State private var errorMessage: String?
    @State private var profileRefreshID = UUID()
    @State private var inviteCodeCopied = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case nickname
        case groupName
        case inviteCode
    }

    private var sanitizedNickname: String { nickname.sanitized }
    private var isProfileValid: Bool {
        profileLocked || (sanitizedNickname.isValidNickname && selectedAvatarURL != nil)
    }
    private var normalizedInterval: Int { Constants.normalizedIntervalSeconds(intervalSeconds) }
    private var inviteCodeReady: Bool { inviteCode.sanitized.uppercased().count == Constants.inviteCodeLength }
    private var sanitizedGroupName: String { groupName.sanitized }
    private var profileLocked: Bool { appState.config.userID != nil }
    private var activeSidebarStep: Step {
        switch step {
        case .createGroup, .joinGroup, .groupCreated:
            return .group
        default:
            return step
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .overlay(Color.onboardingBorder)

            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                Divider()
                    .overlay(Color.onboardingBorder)

                footer
            }
            .background(Color.onboardingSurface)
        }
        .frame(minWidth: 640, idealWidth: 680, maxWidth: 740, minHeight: 340, idealHeight: 365, maxHeight: 390)
        .background(Color.onboardingCanvas)
        .onAppear {
            nickname = appState.config.nickname ?? nickname
            if profileLocked {
                withAnimation(.easeOut(duration: 0.18)) { step = .timing }
            } else {
                DispatchQueue.main.async {
                    focusedField = .nickname
                }
            }
        }
    }

    // MARK: - Shell

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("该提肛了")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.onboardingText)
                Text("初始化")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.onboardingSecondaryText)
            }
            .padding(.top, 20)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            VStack(spacing: 6) {
                ForEach(sidebarSteps) { sidebarStep in
                    sidebarRow(sidebarStep)
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(width: 146)
        .background(Color.onboardingSidebar)
    }

    private func sidebarRow(_ item: SidebarStep) -> some View {
        let isActive = activeSidebarStep == item.id
        let completed = isCompleted(item.id)

        return HStack(spacing: 10) {
            Image(systemName: completed ? "checkmark.circle.fill" : item.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? Color.onboardingAccent : Color.onboardingSecondaryText)
                .frame(width: 20)

            Text(item.title)
                .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.onboardingText : Color.onboardingSecondaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isActive ? Color.white.opacity(0.9) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isActive ? Color.onboardingBorder : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .profile:
            profileContent
        case .timing:
            timingContent
        case .group:
            groupChoiceContent
        case .createGroup:
            createGroupContent
        case .joinGroup:
            joinGroupContent
        case .groupCreated:
            groupCreatedContent
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                goBack()
            } label: {
                Label("返回", systemImage: "chevron.left")
            }
            .buttonStyle(OnboardingSecondaryButtonStyle())
            .disabled(step == .profile || isBusy)

            Spacer()

            primaryFooterButton
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
        .background(Color.onboardingSurface)
    }

    @ViewBuilder
    private var primaryFooterButton: some View {
        switch step {
        case .profile:
            Button {
                Task { await submitProfile() }
            } label: {
                if isCreatingUser {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(profileLocked ? "继续" : "创建资料")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(!isProfileValid || isCreatingUser)

        case .timing:
            Button {
                goForward()
            } label: {
                Label("继续", systemImage: "chevron.right")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())

        case .group:
            if appState.config.hasGroup {
                Button {
                    finishOnboarding()
                } label: {
                    Label("完成", systemImage: "checkmark")
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            } else {
                EmptyView()
            }

        case .createGroup:
            Button {
                Task { await createGroupFromForm() }
            } label: {
                if isCreatingGroup {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("创建")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(sanitizedGroupName.isEmpty || isCreatingGroup)

        case .joinGroup:
            Button {
                Task { await joinGroupFromForm() }
            } label: {
                if isJoiningGroup {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("加入")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(!inviteCodeReady || isJoiningGroup)

        case .groupCreated:
            Button {
                finishOnboarding()
            } label: {
                Label("完成", systemImage: "checkmark")
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
        }
    }

    // MARK: - Profile

    private var profileContent: some View {
        centeredContent(maxWidth: 480) {
            HStack(alignment: .top, spacing: 24) {
                Button {
                    pickAvatar()
                } label: {
                    avatarPreview(size: 96)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .disabled(profileLocked)
                .accessibilityLabel("选择头像")

                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("昵称")

                    TextField("2-12 个字符", text: $nickname)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(nicknameBorderColor, lineWidth: 1)
                        )
                        .focused($focusedField, equals: .nickname)
                        .disabled(profileLocked)
                        .onChange(of: nickname) { _ in
                            let trimmed = nickname.sanitized
                            if trimmed.count > Constants.nicknameMaxLength {
                                nickname = String(trimmed.prefix(Constants.nicknameMaxLength))
                            }
                            errorMessage = nil
                        }
                        .onSubmit {
                            if isProfileValid {
                                Task { await submitProfile() }
                            }
                        }

                    HStack(spacing: 8) {
                        Image(systemName: isProfileValid ? "checkmark.circle.fill" : "photo.badge.plus")
                            .foregroundStyle(isProfileValid ? Color.onboardingSuccess : Color.onboardingSecondaryText)
                        Text(profileLocked ? "资料已创建" : (selectedAvatarURL == nil ? "请选择头像" : "头像已选择"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isProfileValid ? Color.onboardingSuccess : Color.onboardingSecondaryText)
                        Spacer()
                        Text("\(sanitizedNickname.count)/\(Constants.nicknameMaxLength)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.onboardingSecondaryText)
                    }

                    errorView
                }
                .frame(maxWidth: 360, alignment: .leading)
            }
            .id(profileRefreshID)
        }
    }

    private func avatarPreview(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.onboardingMuted)

            if let selectedAvatarImage {
                Image(nsImage: selectedAvatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 30, weight: .semibold))
                    Text("头像")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.onboardingSecondaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.onboardingBorder, lineWidth: 1))
    }

    // MARK: - Timing

    private var timingContent: some View {
        centeredContent {
            VStack(spacing: 10) {
                CircularIntervalPicker(seconds: $intervalSeconds)
                    .frame(width: 150, height: 150)

                Text("当前：\(formatInterval(normalizedInterval))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.onboardingSecondaryText)

                Text(intervalComment)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.onboardingAccent)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.onboardingAccentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var intervalComment: String {
        let name = sanitizedNickname.isEmpty ? "你" : sanitizedNickname

        switch normalizedInterval {
        case 10:
            return "物极必反小心脱肛"
        case ..<1200:
            return "\(name) 你是我的神！"
        case ..<2400:
            return "提肛尊者"
        case ..<3600:
            return "😂"
        case ..<7200:
            return "行不行呀细狗"
        default:
            return "必得痔疮"
        }
    }

    // MARK: - Group

    private var groupChoiceContent: some View {
        centeredContent {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 10) {
                    groupActionButton(
                        symbolName: "plus",
                        title: "创建群组",
                        detail: "生成邀请码。",
                        tint: Color.onboardingAccent
                    ) {
                        step = .createGroup
                    }

                    groupActionButton(
                        symbolName: "person.badge.plus",
                        title: "加入群组",
                        detail: "输入邀请码。",
                        tint: Color.onboardingRose
                    ) {
                        step = .joinGroup
                    }
                }

                if let groupName = appState.config.joinedGroups.first?.groupName {
                    statusBanner(
                        title: "已加入群组",
                        detail: groupName,
                        symbolName: "checkmark.circle.fill",
                        tint: Color.onboardingSuccess
                    )
                }

                errorView
            }
        }
    }

    private func groupActionButton(
        symbolName: String,
        title: String,
        detail: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.onboardingText)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.onboardingSecondaryText)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .padding(.horizontal, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.onboardingBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Group

    private var createGroupContent: some View {
        centeredContent(maxWidth: 360) {
            VStack(alignment: .center, spacing: 14) {
                fieldLabel("群组名称")

                TextField("必填", text: $groupName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14)
                    .frame(width: 360, height: 42)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.onboardingBorder, lineWidth: 1)
                    )
                    .focused($focusedField, equals: .groupName)
                    .onChange(of: groupName) { _ in
                        errorMessage = nil
                    }
                    .onSubmit {
                        Task { await createGroupFromForm() }
                    }

                errorView
            }
        }
        .onAppear {
            focusedField = .groupName
        }
    }

    private var groupCreatedContent: some View {
        centeredContent {
            VStack(alignment: .center, spacing: 16) {
                statusBanner(
                    title: "群组已创建",
                    detail: createdGroupName?.isEmpty == false ? createdGroupName ?? "" : "把邀请码发给朋友。",
                    symbolName: "checkmark.circle.fill",
                    tint: Color.onboardingSuccess
                )

                if let createdInviteCode {
                    VStack(alignment: .center, spacing: 10) {
                        fieldLabel("邀请码")

                        HStack(spacing: 8) {
                            ForEach(Array(createdInviteCode.enumerated()), id: \.offset) { _, char in
                                Text(String(char))
                                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.onboardingText)
                                    .frame(width: 36, height: 46)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.onboardingBorder, lineWidth: 1)
                                    )
                            }

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(createdInviteCode, forType: .string)
                                inviteCodeCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    inviteCodeCopied = false
                                }
                            } label: {
                                if inviteCodeCopied {
                                    Label("已复制", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(Color.onboardingSuccess)
                                } else {
                                    Label("复制", systemImage: "doc.on.doc")
                                }
                            }
                            .buttonStyle(OnboardingSecondaryButtonStyle())
                            .padding(.leading, 8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Join Group

    private var joinGroupContent: some View {
        centeredContent(maxWidth: 260) {
            VStack(alignment: .center, spacing: 14) {
                fieldLabel("邀请码")

                TextField("ABC123", text: $inviteCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .frame(width: 220, height: 46)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(inviteCodeReady || inviteCode.isEmpty ? Color.onboardingBorder : Color.onboardingDanger.opacity(0.55), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .inviteCode)
                    .onChange(of: inviteCode) { _ in
                        inviteCode = String(inviteCode.sanitized.uppercased().prefix(Constants.inviteCodeLength))
                        errorMessage = nil
                    }
                    .onSubmit {
                        if inviteCodeReady {
                            Task { await joinGroupFromForm() }
                        }
                    }

                errorView
            }
        }
        .onAppear {
            focusedField = .inviteCode
        }
    }

    // MARK: - Reusable Pieces

    private func centeredContent<Content: View>(
        maxWidth: CGFloat = 430,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 26)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.onboardingText)
    }

    private func statusBanner(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color = Color.onboardingAccent
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.onboardingText)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.onboardingSecondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: 430, alignment: .leading)
        .background(Color.onboardingMuted)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var errorView: some View {
        if let errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.onboardingDanger)
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.onboardingDanger)
            }
        }
    }

    // MARK: - Navigation

    private func goForward() {
        errorMessage = nil
        switch step {
        case .timing:
            withAnimation(.easeOut(duration: 0.18)) { step = .group }
        default:
            break
        }
    }

    private func goBack() {
        errorMessage = nil
        switch step {
        case .timing:
            clearSavedOnboardingUserData()
            withAnimation(.easeOut(duration: 0.18)) { step = .profile }
        case .group:
            withAnimation(.easeOut(duration: 0.18)) { step = .timing }
        case .createGroup, .joinGroup, .groupCreated:
            withAnimation(.easeOut(duration: 0.18)) { step = .group }
        case .profile:
            break
        }
    }

    private func isCompleted(_ sidebarStep: Step) -> Bool {
        switch sidebarStep {
        case .profile:
            return appState.config.userID != nil || activeSidebarStep.rawValue > Step.profile.rawValue
        case .timing:
            return activeSidebarStep.rawValue > Step.timing.rawValue
        case .group:
            return appState.config.hasGroup
        default:
            return false
        }
    }

    private var nicknameBorderColor: Color {
        if sanitizedNickname.isEmpty { return Color.onboardingBorder }
        return sanitizedNickname.isValidNickname ? Color.onboardingBorder : Color.onboardingDanger
    }

    private var isBusy: Bool {
        isCreatingUser || isCreatingGroup || isJoiningGroup
    }

    private func formatInterval(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒" }
        let minutes = seconds / 60
        let secs = seconds % 60
        if secs > 0 { return "\(minutes) 分 \(secs) 秒" }
        return "\(minutes) 分钟"
    }

    // MARK: - Actions

    private func clearSavedOnboardingUserData() {
        // Delete user from backend if we have a userID
        if let userID = appState.config.userID {
            Task {
                try? await appState.apiClient.deleteUser(userID: userID)
            }
        }

        appState.config.userID = nil
        appState.config.nickname = nil
        appState.config.petEmoji = nil
        appState.config.avatarURL = nil
        appState.config.joinedGroups = []
        appState.config.onboardingComplete = false
        PersistenceManager.shared.onboardingComplete = false
        appState.saveConfig()

        nickname = ""
        selectedAvatarURL = nil
        selectedAvatarImage = nil
        groupName = ""
        inviteCode = ""
        createdInviteCode = nil
        createdGroupName = nil
        profileRefreshID = UUID()

        DispatchQueue.main.async {
            focusedField = .nickname
        }
    }

    private func pickAvatar() {
        guard !profileLocked else { return }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["png", "jpg", "jpeg", "gif", "webp"]

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            selectedAvatarURL = url
            selectedAvatarImage = NSImage(contentsOf: url)
            errorMessage = nil
            profileRefreshID = UUID()
            focusedField = .nickname
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    private func submitProfile() async {
        guard !isCreatingUser else { return }
        if appState.config.userID != nil {
            errorMessage = nil
            withAnimation(.easeOut(duration: 0.18)) { step = .timing }
            return
        }

        guard sanitizedNickname.isValidNickname else {
            focusedField = .nickname
            return
        }
        guard let selectedAvatarURL else {
            errorMessage = "请选择头像"
            return
        }

        isCreatingUser = true
        errorMessage = nil

        do {
            let resp = try await appState.apiClient.createUser(
                nickname: sanitizedNickname,
                avatarURL: selectedAvatarURL
            )
            appState.config.userID = resp.user_id
            appState.config.nickname = resp.nickname
            appState.config.petEmoji = resp.pet_emoji
            appState.config.avatarURL = resp.avatar_url
            appState.saveConfig()
            withAnimation(.easeOut(duration: 0.18)) { step = .timing }
        } catch APIError.serverError(let code, let msg) where code == 409 {
            errorMessage = "昵称已被使用"
            focusedField = .nickname
        } catch APIError.serverError(let code, let msg) where code == 422 {
            if msg.contains("too large") || msg.contains("Avatar is too large") {
                errorMessage = "头像文件太大，请选择更小的图片"
            } else {
                errorMessage = msg
            }
        } catch APIError.invalidFile(let message) {
            errorMessage = message
        } catch {
            errorMessage = "无法创建资料，请检查后端"
        }

        isCreatingUser = false
    }

    private func createGroupFromForm() async {
        guard !isCreatingGroup else { return }
        guard let userID = appState.config.userID else {
            errorMessage = "请先完成资料"
            step = .profile
            return
        }
        guard !sanitizedGroupName.isEmpty else {
            errorMessage = "请输入群组名称"
            focusedField = .groupName
            return
        }

        isCreatingGroup = true
        errorMessage = nil

        do {
            let resp = try await appState.apiClient.createGroup(creatorID: userID, name: sanitizedGroupName)
            appState.addGroup(groupID: resp.group_id, groupName: resp.name, inviteCode: resp.invite_code)
            appState.saveConfig()
            createdInviteCode = resp.invite_code
            createdGroupName = resp.name
            withAnimation(.easeOut(duration: 0.18)) {
                step = .groupCreated
            }
        } catch {
            errorMessage = "创建群组失败"
        }

        isCreatingGroup = false
    }

    private func joinGroupFromForm() async {
        guard !isJoiningGroup else { return }
        guard inviteCodeReady else {
            focusedField = .inviteCode
            return
        }
        guard let userID = appState.config.userID else {
            errorMessage = "请先完成资料"
            step = .profile
            return
        }

        isJoiningGroup = true
        errorMessage = nil

        do {
            let resp = try await appState.apiClient.joinGroup(userID: userID, code: inviteCode.sanitized.uppercased())
            appState.addGroup(groupID: resp.group_id, groupName: resp.name, inviteCode: resp.invite_code)
            appState.saveConfig()
            finishOnboarding()
        } catch {
            errorMessage = "邀请码无效，或你已经在这个群组里"
        }

        isJoiningGroup = false
    }

    private func finishOnboarding() {
        guard appState.config.userID != nil, appState.config.hasGroup else {
            errorMessage = "必须先加入群组"
            step = .group
            return
        }

        appState.config.intervalSeconds = normalizedInterval
        appState.config.petImageName = "pet_deer"
        appState.completeOnboarding()
        onComplete()
    }
}

// MARK: - Onboarding Theme

extension Color {
    static let onboardingCanvas = Color(red: 0.937, green: 0.957, blue: 0.992)
    static let onboardingSidebar = Color(red: 0.902, green: 0.933, blue: 0.988)
    static let onboardingSurface = Color(red: 0.984, green: 0.989, blue: 0.998)
    static let onboardingMuted = Color(red: 0.918, green: 0.945, blue: 0.992)
    static let onboardingBorder = Color(red: 0.765, green: 0.835, blue: 0.949)
    static let onboardingText = Color(red: 0.074, green: 0.118, blue: 0.196)
    static let onboardingSecondaryText = Color(red: 0.337, green: 0.424, blue: 0.557)
    static let onboardingAccent = Color(red: 0.096, green: 0.388, blue: 0.875)
    static let onboardingAccentSoft = Color(red: 0.858, green: 0.910, blue: 0.996)
    static let onboardingRose = Color(red: 0.294, green: 0.463, blue: 0.925)
    static let onboardingDanger = Color(red: 0.740, green: 0.110, blue: 0.145)
    static let onboardingSuccess = Color(red: 0.047, green: 0.518, blue: 0.318)
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .frame(minWidth: 104, minHeight: 38)
            .background(isEnabled ? Color.onboardingAccent : Color.onboardingSecondaryText.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.onboardingText : Color.onboardingSecondaryText.opacity(0.55))
            .padding(.horizontal, 16)
            .frame(minHeight: 38)
            .background(Color.white.opacity(isEnabled ? 1 : 0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.onboardingBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
