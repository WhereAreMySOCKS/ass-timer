import SwiftUI

/// View for joining an existing group via a 6-character invite code.
struct JoinGroupView: View {
    @ObservedObject var appState: AppState
    var onJoin: (String, String) async -> Bool
    var onBack: () -> Void

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("加入群组")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.charcoalText)

                Text("输入6位邀请码")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Clay digit cards with hidden text field for input
            ZStack {
                // Visible digit cards
                HStack(spacing: 10) {
                    ForEach(0..<Constants.inviteCodeLength, id: \.self) { index in
                        let char = index < inviteCode.count
                            ? String(inviteCode[inviteCode.index(inviteCode.startIndex, offsetBy: index)])
                            : ""
                        Text(char)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
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
                                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 2, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        char.isEmpty ? Color.gray.opacity(0.15) : Color.accent.opacity(0.3),
                                        lineWidth: 1.2
                                    )
                            )
                            // Blinking cursor on next empty slot
                            .overlay(
                                Group {
                                    if index == inviteCode.count && !isJoining {
                                        Capsule()
                                            .fill(Color.accent)
                                            .frame(width: 2, height: 24)
                                            .opacity(cursorVisible ? 1 : 0)
                                    }
                                }
                            )
                    }
                }

                // Hidden text field that receives keyboard input
                TextField("", text: $inviteCode)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.clear)
                    .tint(.clear)
                    .frame(maxWidth: 260)
                    .opacity(0.015)
                    .onChange(of: inviteCode) { _ in
                        inviteCode = String(inviteCode.uppercased().prefix(Constants.inviteCodeLength))
                        errorMessage = nil
                    }
            }
            .onAppear {
                startCursorBlink()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.coral)
            }

            Button {
                Task {
                    isJoining = true
                    errorMessage = nil
                    let success = await onJoin(appState.config.userID ?? "", inviteCode)
                    isJoining = false
                    if !success {
                        errorMessage = "邀请码无效或已在群组中"
                    }
                }
            } label: {
                HStack {
                    if isJoining {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text("加入群组")
                }
            }
            .buttonStyle(ClayPrimaryButtonStyle())
            .disabled(inviteCode.count != Constants.inviteCodeLength || isJoining)

            Button("返回") { onBack() }
                .buttonStyle(ClaySecondaryButtonStyle())
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
    }

    // MARK: - Cursor Blink

    @State private var cursorVisible = true

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if inviteCode.count >= Constants.inviteCodeLength {
                timer.invalidate()
                cursorVisible = false
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                cursorVisible.toggle()
            }
        }
    }
}
