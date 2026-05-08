import SwiftUI

struct ProgressRing: View {
    let value: Double // 0...1
    let label: String
    var lineWidth: CGFloat = 8
    var tint: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: value)
            Text(label)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .frame(width: 72, height: 72)
    }
}
