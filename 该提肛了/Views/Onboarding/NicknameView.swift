import SwiftUI

struct NicknameView: View {
    @Binding var nickname: String
    var petImageName: String
    var onNext: () -> Void
    var onBack: () -> Void

    @State private var errorMessage: String?
    private var isValid: Bool { nickname.sanitized.isValidNickname }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("你的昵称")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.charcoalText)
                Text("\(Constants.nicknameMinLength)–\(Constants.nicknameMaxLength) 个字符，群组成员可见")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Live avatar preview — deer image + nickname
            HStack(spacing: 16) {
                // Pet image avatar
                Group {
                    if let nsImage = NSImage(named: petImageName) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "hare.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accent)
                    }
                }
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.claySurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.9), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 2, y: 3)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(nickname.sanitized.isEmpty ? "你的昵称" : nickname.sanitized)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(nickname.sanitized.isEmpty ? .secondary : .charcoalText)
                    Text("小鹿的搭档")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)

            // Circular character counter ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 4)
                    .frame(width: 44, height: 44)
                // Filled ring
                Circle()
                    .trim(from: 0, to: min(CGFloat(nickname.sanitized.count) / CGFloat(Constants.nicknameMaxLength), 1.0))
                    .stroke(
                        nickname.sanitized.count >= Constants.nicknameMinLength ? Color.accent : Color.coral,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.35), value: nickname.sanitized.count)
                // Center text
                Text("\(nickname.sanitized.count)/\(Constants.nicknameMaxLength)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(nickname.sanitized.count >= Constants.nicknameMinLength ? .secondary : .coral)
            }
            .padding(.top, 4)

            // Styled text field
            TextField("输入昵称", text: $nickname)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.claySurface)
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 1, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            nickname.sanitized.isEmpty ? Color.gray.opacity(0.15) : Color.accent.opacity(0.4),
                            lineWidth: 1.2
                        )
                )
                .frame(maxWidth: 260)
                .onChange(of: nickname) { _ in
                    let sanitized = nickname.sanitized
                    if sanitized.count > Constants.nicknameMaxLength {
                        nickname = String(sanitized.prefix(Constants.nicknameMaxLength))
                    }
                    errorMessage = nil
                }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                Button("返回") { onBack() }
                    .buttonStyle(ClaySecondaryButtonStyle())
                Button("继续") { onNext() }
                    .buttonStyle(ClayPrimaryButtonStyle())
                    .disabled(!isValid)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}
