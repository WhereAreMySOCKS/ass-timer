import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CustomActionMediaEditorRequest: Identifiable {
    let id = UUID()
    let slot: CustomActionSlot
    let importedURL: URL?
}

struct CustomActionMediaSettingsView: View {
    @ObservedObject var appState: AppState

    @State private var editorRequest: CustomActionMediaEditorRequest?
    @State private var slotToReset: CustomActionSlot?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("动作素材")
                        .font(.headline)
                    Text("为不同动作设置照片；未设置时显示默认素材。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(CustomActionSlot.allCases) { slot in
                        mediaCard(for: slot)
                    }
                }
            }
            .padding(14)
        }
        .sheet(item: $editorRequest) { request in
            CustomActionMediaEditorView(appState: appState, request: request)
        }
        .alert("恢复默认素材？", isPresented: Binding(
            get: { slotToReset != nil },
            set: { if !$0 { slotToReset = nil } }
        )) {
            Button("恢复默认", role: .destructive) {
                if let slot = slotToReset {
                    appState.removeCustomActionMedia(for: slot)
                }
                slotToReset = nil
            }
            Button("取消", role: .cancel) {
                slotToReset = nil
            }
        } message: {
            Text("将删除这张本地照片及其处理结果，之后恢复显示内置素材。")
        }
    }

    private func mediaCard(for slot: CustomActionSlot) -> some View {
        let entry = appState.config.customActionMedia[slot]
        let customPreview = entry.flatMap { appState.customActionMediaStore.image(for: $0) }
        let preview = customPreview ?? SpriteLoader.loadSprite(named: slot.defaultSpriteName)

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.05))

                if let preview {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .frame(height: 76)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            }
            .accessibilityLabel(entry == nil ? "\(slot.title)默认素材" : "\(slot.title)当前素材")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(slot.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if entry?.removesBackground == true {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .accessibilityLabel("已去背景")
                    } else if entry == nil {
                        Text("默认")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text(detail(for: slot))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if entry == nil {
                        Button("选择照片…") {
                            choosePhoto(for: slot)
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("编辑") {
                            editorRequest = CustomActionMediaEditorRequest(slot: slot, importedURL: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Menu {
                            Button("更换照片…") {
                                choosePhoto(for: slot)
                            }
                            Divider()
                            Button("恢复默认", role: .destructive) {
                                slotToReset = slot
                            }
                        } label: {
                            Label("更多", systemImage: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func detail(for slot: CustomActionSlot) -> String {
        if slot == .completion, appState.config.appMode == .obedient {
            return "完成放松后"
        }
        return slot.detail
    }

    private func choosePhoto(for slot: CustomActionSlot) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP]
        panel.message = "选择用于“\(slot.title)”动作的照片（最大 10MB）"
        panel.prompt = "编辑"

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            editorRequest = CustomActionMediaEditorRequest(slot: slot, importedURL: url)
        }
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }
}

private struct CustomActionMediaEditorView: View {
    @ObservedObject var appState: AppState
    let request: CustomActionMediaEditorRequest

    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomActionMediaDraft?
    @State private var isLoading = true
    @State private var isRemovingBackground = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var processingTask: Task<Void, Never>?
    @State private var processingID: UUID?

    private var supportsBackgroundRemoval: Bool {
        if #available(macOS 14.0, *) { return true }
        return false
    }

    private var removeBackgroundBinding: Binding<Bool> {
        Binding(
            get: { draft?.removesBackground == true },
            set: { setRemoveBackground($0) }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("编辑“\(request.slot.title)”素材")
                .font(.headline)

            Group {
                if isLoading {
                    ZStack {
                        checkerboard
                        ProgressView("正在读取图片…")
                    }
                } else if let image = previewImage {
                    ZStack {
                        checkerboard
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                } else {
                    ZStack {
                        checkerboard
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 162, height: request.slot.usesSquarePreview ? 162 : 216)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            }
            .accessibilityLabel("动作素材预览")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Toggle("去除背景", isOn: removeBackgroundBinding)
                        .toggleStyle(.checkbox)
                        .disabled(!supportsBackgroundRemoval || isLoading || draft == nil || isSaving)

                    if isRemovingBackground {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在识别主体…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !supportsBackgroundRemoval {
                    Text("去除背景需要 macOS 14 或更高版本")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("在本机识别前景，不会上传照片。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("错误：\(errorMessage)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("取消") {
                    processingTask?.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    Task { await save() }
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSaving ? "保存中…" : "保存")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft == nil || isLoading || isRemovingBackground || isSaving)
            }
        }
        .padding(20)
        .frame(width: 360)
        .task { await loadDraft() }
        .onDisappear {
            processingTask?.cancel()
            processingTask = nil
            processingID = nil
        }
    }

    private var previewImage: NSImage? {
        guard let draft else { return nil }
        let data = draft.removesBackground
            ? (draft.foregroundPNG ?? draft.backgroundPNG)
            : draft.backgroundPNG
        return NSImage(data: data)
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cell: CGFloat = 12
            let columns = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0..<rows {
                for column in 0..<columns {
                    let color = (row + column).isMultiple(of: 2)
                        ? Color(nsColor: .controlBackgroundColor)
                        : Color.primary.opacity(0.08)
                    let rect = CGRect(
                        x: CGFloat(column) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func loadDraft() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let importedURL = request.importedURL {
                draft = try await appState.customActionMediaStore.prepareDraft(
                    from: importedURL,
                    slot: request.slot
                )
            } else if let entry = appState.config.customActionMedia[request.slot] {
                draft = try await appState.customActionMediaStore.loadDraft(entry: entry)
            } else {
                throw CustomActionMediaError.missingFiles
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "无法读取素材"
        }
    }

    private func setRemoveBackground(_ enabled: Bool) {
        guard var currentDraft = draft else { return }
        errorMessage = nil

        if !enabled {
            processingTask?.cancel()
            processingTask = nil
            processingID = nil
            isRemovingBackground = false
            currentDraft.removesBackground = false
            draft = currentDraft
            return
        }

        guard supportsBackgroundRemoval else { return }
        if currentDraft.foregroundPNG != nil {
            currentDraft.removesBackground = true
            draft = currentDraft
            return
        }

        currentDraft.removesBackground = true
        draft = currentDraft
        isRemovingBackground = true
        let sourceData = currentDraft.sourceData
        let id = UUID()
        processingID = id
        processingTask?.cancel()
        processingTask = Task {
            do {
                let foregroundPNG = try await appState.customActionMediaStore.generateForegroundPNG(
                    from: sourceData,
                    slot: request.slot
                )
                guard processingID == id, !Task.isCancelled, var updatedDraft = draft else { return }
                updatedDraft.foregroundPNG = foregroundPNG
                updatedDraft.removesBackground = true
                draft = updatedDraft
                isRemovingBackground = false
                processingTask = nil
                processingID = nil
            } catch is CancellationError {
                guard processingID == id else { return }
                isRemovingBackground = false
                processingTask = nil
                processingID = nil
            } catch {
                guard processingID == id, var updatedDraft = draft else { return }
                updatedDraft.removesBackground = false
                draft = updatedDraft
                isRemovingBackground = false
                processingTask = nil
                processingID = nil
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "去除背景失败，请重试"
            }
        }
    }

    private func save() async {
        guard let draft else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await appState.saveCustomActionMedia(draft, for: request.slot)
            dismiss()
        } catch {
            errorMessage = "保存素材失败，请检查磁盘空间后重试"
        }
    }
}
