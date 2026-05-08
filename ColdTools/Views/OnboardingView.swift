import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Binding var completed: Bool

    @State private var page = 0
    @State private var baselineCigs = 20
    @State private var targetCigs = 12
    @State private var packPrice: Double = 25
    @State private var waterGoal = 2000
    @State private var selectedTheme: AppTheme = .warmAmber
    @FocusState private var priceFocused: Bool

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [
                    selectedTheme.light.opacity(0.15),
                    selectedTheme.light.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    themePage.tag(1)
                    baselinePage.tag(2)
                    pricePage.tag(3)
                    waterPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth, value: page)

                pageIndicator

                Button {
                    next()
                } label: {
                    Text(page == 4 ? "开始使用" : "下一步")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .foregroundStyle(.white)
                        .background {
                            Capsule()
                                .fill(selectedTheme.light.gradient)
                                .shadow(color: selectedTheme.light.opacity(0.35), radius: 10, y: 4)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { priceFocused = false }.fontWeight(.semibold)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 5, id: \.self) { idx in
                Capsule()
                    .fill(idx == page ? selectedTheme.light : Color.secondary.opacity(0.3))
                    .frame(width: idx == page ? 24 : 8, height: 8)
                    .animation(.smooth, value: page)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "snowflake")
                .font(.system(size: 100, weight: .light))
                .foregroundStyle(selectedTheme.light.gradient)
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text("cold tools")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("冷静记录 · 温柔坚持")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                feature(icon: "nosign", tint: .red, title: "戒烟追踪", desc: "记录每一根，看见减少")
                feature(icon: "drop.fill", tint: .blue, title: "喝水打卡", desc: "简单的 4 个按钮完成目标")
                feature(icon: "trophy.fill", tint: .orange, title: "成就激励", desc: "坚持的每一天都有见证")
                feature(icon: "lock.shield.fill", tint: .green, title: "隐私保护", desc: "Face ID 加密锁，数据只在本机")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func feature(icon: String, tint: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background { Circle().fill(tint.opacity(0.15)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var themePage: some View {
        VStack(spacing: 20) {
            pageTitle("选一个你喜欢的主题色", icon: "paintpalette.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(AppTheme.allCases) { t in
                    Button {
                        Haptics.selection()
                        withAnimation(.smooth) { selectedTheme = t }
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(t.light.gradient)
                                .frame(width: 50, height: 50)
                                .shadow(color: t.light.opacity(0.3), radius: 6, y: 2)
                                .overlay {
                                    if selectedTheme == t {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            Text(t.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                        .overlay {
                            if selectedTheme == t {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(t.light, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var baselinePage: some View {
        VStack(spacing: 24) {
            pageTitle("你平时每天抽多少根？", icon: "chart.line.downtrend.xyaxis")
            Text("我们会帮你慢慢减下来")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 20) {
                bigStepper(value: $baselineCigs, range: 1 ... 80, label: "每天正常", tint: .red)
                bigStepper(value: $targetCigs, range: 0 ... baselineCigs, label: "今日目标", tint: selectedTheme.light)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var pricePage: some View {
        VStack(spacing: 24) {
            pageTitle("一包烟多少钱？", icon: "yensign.circle.fill")
            Text("用省下的钱激励自己")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("¥")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.secondary)
                    TextField("25", value: $packPrice, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedTheme.light)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: true, vertical: false)
                        .focused($priceFocused)
                }
                Text("每包价格")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(30)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 32)

            // 常见价格快捷
            HStack(spacing: 8) {
                ForEach([15, 20, 25, 30, 50, 100], id: \.self) { p in
                    Button {
                        Haptics.tap()
                        packPrice = Double(p)
                    } label: {
                        Text("¥\(p)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    private var waterPage: some View {
        VStack(spacing: 24) {
            pageTitle("每天喝多少水？", icon: "drop.fill")
            Text("多喝水帮助尼古丁代谢")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                ForEach([(1500, "1.5L", "轻度活动"), (2000, "2.0L", "推荐"), (2500, "2.5L", "运动较多"), (3000, "3.0L", "户外工作")], id: \.0) { item in
                    Button {
                        Haptics.selection()
                        waterGoal = item.0
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "drop.fill")
                                .font(.title3)
                                .foregroundStyle(waterGoal == item.0 ? .white : .blue)
                                .frame(width: 42, height: 42)
                                .background {
                                    Circle().fill(waterGoal == item.0 ? Color.blue : Color.blue.opacity(0.15))
                                }
                            VStack(alignment: .leading) {
                                Text(item.1)
                                    .font(.title3.weight(.bold))
                                Text(item.2)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if waterGoal == item.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                            }
                        }
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                        .overlay {
                            if waterGoal == item.0 {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(.blue, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func pageTitle(_ text: String, icon: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(selectedTheme.light.gradient)
                .padding(.top, 40)
            Text(text)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func bigStepper(value: Binding<Int>, range: ClosedRange<Int>, label: String, tint: Color) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Button {
                if value.wrappedValue > range.lowerBound {
                    Haptics.tap()
                    value.wrappedValue -= 1
                }
            } label: {
                Image(systemName: "minus")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)

            Text("\(value.wrappedValue)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .frame(width: 60)
                .contentTransition(.numericText())
                .animation(.snappy, value: value.wrappedValue)

            Button {
                if value.wrappedValue < range.upperBound {
                    Haptics.tap()
                    value.wrappedValue += 1
                }
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func next() {
        Haptics.tap(.medium)
        priceFocused = false
        if page < 4 {
            withAnimation(.smooth) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        let settings = AppSettingsStore.current(in: context)
        settings.baselineCigs = baselineCigs
        settings.targetCigs = targetCigs
        settings.packPrice = packPrice
        settings.waterGoalML = waterGoal
        settings.themeRaw = selectedTheme.rawValue
        try? context.save()
        _ = UsageMarkerStore.current(in: context)
        withAnimation(.smooth) { completed = true }
    }
}
