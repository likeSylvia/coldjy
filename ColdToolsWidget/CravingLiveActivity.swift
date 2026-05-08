import ActivityKit
import WidgetKit
import SwiftUI

struct CravingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CravingAttributes.self) { context in
            lockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                        Text("烟瘾计时")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    progressRing(context: context)
                        .frame(width: 48, height: 48)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.startDate, style: .timer)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("坚持住，5 分钟后烟瘾会消退")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.startDate, style: .timer)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(width: 48)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<CravingAttributes>) -> some View {
        HStack(spacing: 16) {
            progressRing(context: context)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("烟瘾计时")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(context.state.startDate, style: .timer)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(context.state.resisted ? "已忍住" : "坚持住，会过去的")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func progressRing(context: ActivityViewContext<CravingAttributes>) -> some View {
        ZStack {
            Circle()
                .stroke(.orange.opacity(0.2), lineWidth: 5)
            Circle()
                .stroke(.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(0.85)
            Image(systemName: "nosign")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.orange)
        }
    }
}
