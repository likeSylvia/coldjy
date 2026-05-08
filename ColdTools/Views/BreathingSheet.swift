import SwiftUI

struct BreathingSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum RunState {
        case idle
        case running(phase: Int, cycle: Int, remaining: Int)
        case completed
    }

    @State private var state: RunState = .idle
    @State private var ticker: Timer?
    @State private var totalCycles = BreathingCycle.cyclesDefault
    @State private var scale: CGFloat = 1.0

    private var phases: [BreathingPhase] { BreathingCycle.phases }

    var body: some View {
        VStack(spacing: 24) {
            header

            Spacer()

            // 呼吸球
            ZStack {
                Circle()
                    .fill(currentColor.opacity(0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 30)
                    .scaleEffect(scale * 1.1)

                Circle()
                    .fill(currentColor.gradient.opacity(0.3))
                    .frame(width: 260, height: 260)
                    .scaleEffect(scale)

                Circle()
                    .fill(currentColor.gradient.opacity(0.6))
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .overlay {
                        Text(phaseTitle)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.opacity)
                    }
            }
            .animation(.easeInOut(duration: 0.6), value: scale)

            if case .running(_, let cycle, let remaining) = state {
                VStack(spacing: 6) {
                    Text("\(remaining)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("第 \(cycle + 1) / \(totalCycles) 轮")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if case .completed = state {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("完成！感受一下身体的变化")
                        .font(.headline)
                }
            } else {
                VStack(spacing: 8) {
                    Text("4-7-8 深呼吸")
                        .font(.title2.bold())
                    Text("吸气 4 秒 · 屏住 7 秒 · 呼气 8 秒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("重复 \(totalCycles) 次，共约 1-2 分钟")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
        }
        .onDisappear {
            ticker?.invalidate()
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
            Spacer()
            if case .idle = state {
                Stepper("\(totalCycles) 轮", value: $totalCycles, in: 2...10)
                    .fixedSize()
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var currentColor: Color {
        switch state {
        case .running(let p, _, _):
            switch phases[p].color {
            case .blue: return .blue
            case .purple: return .purple
            case .green: return .green
            }
        default:
            return .accentColor
        }
    }

    private var phaseTitle: String {
        switch state {
        case .running(let p, _, _): return phases[p].title
        case .completed: return "完成"
        default: return "准备"
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .idle:
            Button {
                start()
            } label: {
                Text("开始")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .contentShape(Capsule())
                    .background {
                        Capsule().fill(Color.accentColor.gradient)
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
        case .running:
            Button {
                stop()
            } label: {
                Text("结束")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.primary)
                    .contentShape(Capsule())
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(PressScaleButtonStyle())
        case .completed:
            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .contentShape(Capsule())
                    .background {
                        Capsule().fill(Color.green.gradient)
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }

    private func start() {
        Haptics.tap(.medium)
        startPhase(cycle: 0, phase: 0)
    }

    private func startPhase(cycle: Int, phase: Int) {
        ticker?.invalidate()
        let d = phases[phase].duration
        state = .running(phase: phase, cycle: cycle, remaining: d)

        // 呼吸球缩放
        withAnimation(.easeInOut(duration: Double(d))) {
            switch phases[phase].id {
            case "inhale": scale = 1.35
            case "hold": scale = 1.35
            case "exhale": scale = 0.85
            default: scale = 1.0
            }
        }
        Haptics.tap(.light)

        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            guard case .running(let p, let c, let r) = state else { t.invalidate(); return }
            if r > 1 {
                state = .running(phase: p, cycle: c, remaining: r - 1)
            } else {
                t.invalidate()
                advanceFrom(cycle: c, phase: p)
            }
        }
    }

    private func advanceFrom(cycle: Int, phase: Int) {
        if phase + 1 < phases.count {
            startPhase(cycle: cycle, phase: phase + 1)
        } else if cycle + 1 < totalCycles {
            startPhase(cycle: cycle + 1, phase: 0)
        } else {
            complete()
        }
    }

    private func stop() {
        ticker?.invalidate()
        state = .idle
        scale = 1.0
    }

    private func complete() {
        ticker?.invalidate()
        state = .completed
        scale = 1.0
        Haptics.success()
    }
}
