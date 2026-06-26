import SwiftUI

/// Message input bar with text field and send button.
struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("输入消息...", text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.94))
                )
                .onSubmit {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accent)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
