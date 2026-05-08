import SwiftUI

struct TriggerPickerSheet: View {
    let onSelect: (String) -> Void
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("这根烟的诱因是？")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Self.options) { item in
                        Button {
                            Haptics.tap()
                            onSelect(item.name)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.title3)
                                Text(item.name).font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    onSelect("")
                    dismiss()
                } label: {
                    Text("不标注诱因").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.horizontal, 16)
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
}
