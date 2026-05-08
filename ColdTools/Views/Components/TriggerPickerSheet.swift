import SwiftUI
import SwiftData

struct TriggerPickerSheet: View {
    let context: ModelContext
    let onSelect: (String, Date) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var theme
    @Environment(\.colorScheme) private var scheme

    private struct TriggerOption: Identifiable {
        let id: String
        let icon: String
        var name: String { id }
    }

    private static let options: [TriggerOption] = [
        TriggerOption(id: "饭后", icon: "fork.knife"),
        TriggerOption(id: "压力", icon: "bolt.fill"),
        TriggerOption(id: "无聊", icon: "face.smiling"),
        TriggerOption(id: "社交", icon: "person.2.fill"),
        TriggerOption(id: "习惯", icon: "arrow.triangle.2.circlepath"),
        TriggerOption(id: "情绪", icon: "cloud.rain.fill"),
        TriggerOption(id: "提神", icon: "cup.and.saucer.fill"),
        TriggerOption(id: "其他", icon: "questionmark"),
    ]

    enum TimeChoice: Hashable {
        case now
        case minutes(Int)
        case custom
    }

    @State private var timeChoice: TimeChoice = .now
    @State private var customTime: Date = .now
    @State private var showCustomPicker = false

    private var themeColor: Color {
        theme.tintColor(scheme: scheme)
    }

    private var resolvedDate: Date {
        switch timeChoice {
        case .now: return .now
        case .minutes(let m): return Date.now.addingTimeInterval(Double(-m * 60))
        case .custom:
            // 用今天的年月日 + 选的时分
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            let hm = cal.dateComponents([.hour, .minute], from: customTime)
            return cal.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: today) ?? customTime
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    timeSection
                    triggerSection
                    noTriggerButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("记录一根")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .tint(themeColor)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("什么时候抽的")

            HStack(spacing: 8) {
                timeChip("刚刚", choice: .now)
                timeChip("5 分钟前", choice: .minutes(5))
                timeChip("15 分钟前", choice: .minutes(15))
                timeChip("30 分钟前", choice: .minutes(30))
            }

            // 可展开的自定义时间行 —— 整行都可点
            Button {
                Haptics.selection()
                withAnimation(.smooth(duration: 0.25)) {
                    showCustomPicker.toggle()
                    if showCustomPicker {
                        timeChoice = .custom
                        customTime = .now
                    } else if case .custom = timeChoice {
                        timeChoice = .now
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                    Text("自定义时间")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if case .custom = timeChoice {
                        Text(shortTimeString(customTime))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeColor)
                            .monospacedDigit()
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(showCustomPicker ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if showCustomPicker {
                DatePicker("", selection: $customTime, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onChange(of: customTime) { _, _ in
                        timeChoice = .custom
                    }
            }
        }
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("诱因")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Self.options) { item in
                    Button {
                        Haptics.tap(.medium)
                        onSelect(item.name, resolvedDate)
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundStyle(themeColor)
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }

    private var noTriggerButton: some View {
        Button {
            Haptics.tap()
            onSelect("", resolvedDate)
            dismiss()
        } label: {
            Text("不标注诱因，直接记录")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func timeChip(_ label: String, choice: TimeChoice) -> some View {
        let selected: Bool = {
            switch (timeChoice, choice) {
            case (.now, .now): return true
            case (.minutes(let a), .minutes(let b)): return a == b
            case (.custom, .custom): return true
            default: return false
            }
        }()

        return Button {
            Haptics.selection()
            timeChoice = choice
            if case .custom = choice {
                showCustomPicker = true
            }
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(selected ? Color.white : .primary)
                .background {
                    if selected {
                        Capsule().fill(themeColor.gradient)
                    } else {
                        Capsule().fill(themeColor.opacity(0.08))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shortTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
