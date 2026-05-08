import SwiftUI

struct TriggerPickerSheet: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    static let triggers: [(String, String)] = [
        ("饭后", "fork.knife"),
        ("压力", "bolt.fill"),
        ("无聊", "face.smiling"),
        ("社交", "person.2.fill"),
        ("习惯", "arrow.triangle.2.circlepath"),
        ("情绪", "cloud.rain.fill"),
        ("提神", "cup.and.saucer.fill"),
        ("其他", "questionmark"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("这根烟的诱因是？")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Self.triggers, id: \.0) { item in
                        Button {
                            Haptics.tap()
                            onSelect(item.0)
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: item.1)
                                    .font(.title3)
                                Text(item.0).font(.caption)
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
