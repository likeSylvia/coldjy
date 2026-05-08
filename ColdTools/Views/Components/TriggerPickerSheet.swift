import SwiftUI
import SwiftData

struct TriggerPickerSheet: View {
    let context: ModelContext
    let onSelect: (String, Date) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

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
    @State private var customDate: Date = .now
    @State private var selectedTrigger: String?

    private var resolvedDate: Date {
        switch timeChoice {
        case .now: return .now
        case .minutes(let m): return Date.now.addingTimeInterval(Double(-m * 60))
        case .custom: return customDate
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 时间选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("什么时候抽的")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            timeChip("刚刚", choice: .now)
                            timeChip("5 分钟前", choice: .minutes(5))
                            timeChip("15 分钟前", choice: .minutes(15))
                            timeChip("30 分钟前", choice: .minutes(30))
                        }

                        Button {
                            Haptics.selection()
                            if case .custom = timeChoice {
                                timeChoice = .now
                            } else {
                                timeChoice = .custom
                                customDate = .now
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                Text(timeChoice == .custom ? "自定义时间" : "选其他时间")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Image(systemName: timeChoice == .custom ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundStyle(timeChoice == .custom ? Color.accentColor : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        if case .custom = timeChoice {
                            DatePicker("", selection: $customDate, in: ...Date.now)
                                .datePickerStyle(.graphical)
                                .padding(.horizontal, 8)
                                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                        }
                    }

                    // 诱因选择
                    VStack(alignment: .leading, spacing: 10) {
                        Text("诱因")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)

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
                                        Text(item.name).font(.caption)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 68)
                                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        onSelect("", resolvedDate)
                        dismiss()
                    } label: {
                        Text("不标注诱因，直接记录")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
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
        }
    }

    private func timeChip(_ label: String, choice: TimeChoice) -> some View {
        Button {
            Haptics.selection()
            timeChoice = choice
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background {
                    Capsule()
                        .fill(timeChoice == choice ? Color.accentColor.gradient : Color.accentColor.opacity(0.08).gradient)
                }
                .foregroundStyle(timeChoice == choice ? Color.white : .primary)
        }
        .buttonStyle(.plain)
    }
}
