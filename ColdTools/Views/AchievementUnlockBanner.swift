import SwiftUI

/// 成就解锁后顶部弹出的横幅
struct AchievementUnlockBanner: View {
    let achievement: Achievement
    @State private var visible: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.tint.gradient)
                    .frame(width: 52, height: 52)
                    .shadow(color: achievement.tint.opacity(0.5), radius: 8, y: 3)
                Image(systemName: achievement.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("成就解锁")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(achievement.tint)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(achievement.title)
                    .font(.subheadline.weight(.bold))
                Text(achievement.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
        .offset(y: visible ? 0 : -120)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { visible = true }
            Haptics.success()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeOut(duration: 0.3)) { visible = false }
            }
        }
    }
}
