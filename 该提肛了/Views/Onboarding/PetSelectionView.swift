import SwiftUI

/// Pet introduction view — showcases the deer companion (only pet option).
struct PetSelectionView: View {
    @Binding var selectedImageName: String
    var onNext: () -> Void
    var onBack: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("你的伙伴")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.charcoalText)
                Text("小鹿会陪你一起提肛")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 8)

            // Single large clay card showcasing the deer
            VStack(spacing: 12) {
                Group {
                    if let nsImage = NSImage(named: "pet_deer") {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    } else {
                        Image(systemName: "hare.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.accent)
                    }
                }
                .frame(width: 96, height: 96)

                Text("小鹿")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.charcoalText)
            }
            .frame(width: 160, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.claySurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 12, x: 4, y: 6)
            )
            // Selected glow (always on since there's only one pet)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.accent, lineWidth: 2.5)
            )
            .shadow(color: Color.accent.opacity(0.2), radius: 10, x: 0, y: 0)
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            .onHover { isHovering = $0 }
            .onTapGesture {
                selectedImageName = "pet_deer"
            }

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                Button("返回") { onBack() }
                    .buttonStyle(ClaySecondaryButtonStyle())
                Button("继续") { onNext() }
                    .buttonStyle(ClayPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            selectedImageName = "pet_deer"
        }
    }
}
