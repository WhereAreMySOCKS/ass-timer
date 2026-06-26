import SwiftUI

/// Root content view — not directly used since AppDelegate manages windows manually.
/// Kept as a fallback reference; the real UI is managed by AppDelegate.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.core.training")
                .font(.system(size: 48))
                .foregroundColor(.accent)

            Text("Ass-Timer")
                .font(.title)
                .fontWeight(.bold)

            Text("桌面宠物运行中")
                .foregroundColor(.secondary)

            Text("请查看屏幕右下角的宠物")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
