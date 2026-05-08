import SwiftUI
import SwiftData

struct CravingTimerSheet: View {
    @Bindable var timer: CravingTimer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var suggestedAlternative: AlternativeAction = Alternatives.random()
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 大圆盘
            ZStack {
                // 外层光晕
                Circle()
                    .fill(Color.accentColor.opacity(pulse ? 0.25 : 0.10))
                    .frame(width: 300)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

                // 进度环
                Circle()
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 14)
                    .frame(width: 260, height: 260)

                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(Color.accentColor.gradient,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress)

                // 时间显示
                VStack(spacing: 10) {
                    switch timer.state {
                    case .idle:
                        Text("准备好了吗")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("5:00")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    case .running:
                        Text(timer.progress >= 1 ? "已达成" : "坚持住")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(timer.progress >= 1 ? .green : .accentColor)
                        Text(Fmt.duration(Int(timer.currentElapsed)))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.tint)
                            .contentTransition(.numericText())
                    case .finished(let d):
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("坚持了 \(Fmt.duration(Int(d)))")
                            .font(.title3.weight(.semibold))
                    }
                }
            }

            Spacer()

            // 说明区
            VStack(spacing: 12) {
                if case .idle = timer.state {
                    Text("烟瘾通常 3-5 分钟就会消退")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    alternativeCard
                } else if case .running = timer.state {
                    HStack(spacing: 8) {
                        Image(systemName: suggestedAlternative.icon)
                            .foregroundStyle(.tint)
                        Text("试试：\(suggestedAlternative.title)")
                            .font(.subheadline.weight(.medium))
                        Button {
                            suggestedAlternative = Alternatives.random(excluding: suggestedAlternative.id)
                            Haptics.tap()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                    .padding(12)
                    .glassEffect(.regular, in: .capsule)
                } else if case .finished = timer.state {
                    Text("太棒了，已自动记为「忍住一次」")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // 操作按钮
            HStack(spacing: 14) {
                switch timer.state {
                case .idle:
                    Button {
                        timer.start()
                    } label: {
                        Text("开始倒计时")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background {
                                Capsule().fill(Color.accentColor.gradient)
                                    .shadow(color: .accentColor.opacity(0.3), radius: 10, y: 4)
                            }
                    }
                    .buttonStyle(.plain)
                case .running:
                    Button {
                        dismiss()
                    } label: {
                        Text("先不忍了")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.primary)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .buttonStyle(.plain)

                    Button {
                        let duration = timer.complete()
                        recordResisted(duration: duration)
                    } label: {
                        Text("忍住了")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background {
                                Capsule().fill(Color.green.gradient)
                                    .shadow(color: .green.opacity(0.3), radius: 10, y: 4)
                            }
                    }
                    .buttonStyle(.plain)
                case .finished:
                    Button {
                        timer.reset()
                        dismiss()
                    } label: {
                        Text("完成")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background {
                                Capsule().fill(Color.green.gradient)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .onAppear { pulse = true }
    }

    private var alternativeCard: some View {
        VStack(spacing: 10) {
            Text("这段时间可以做点别的")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 14) {
                Image(systemName: suggestedAlternative.icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background {
                        Circle().fill(Color.accentColor.opacity(0.15))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestedAlternative.title)
                        .font(.subheadline.weight(.semibold))
                    Text(suggestedAlternative.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(suggestedAlternative.duration)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    suggestedAlternative = Alternatives.random(excluding: suggestedAlternative.id)
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
    }

    private func recordResisted(duration: TimeInterval) {
        let c = CravingLog(at: .now, trigger: "", intensity: 3, resisted: true, note: "烟瘾计时：\(Int(duration))秒")
        context.insert(c)
        try? context.save()
    }
}
