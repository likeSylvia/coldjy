import SwiftUI

/// 自定义滑动删除行,因为我们不用 List,需要手写左滑交互
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var showDelete: Bool = false
    @GestureState private var dragOffset: CGFloat = 0

    private let buttonWidth: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            // 删除按钮背景
            HStack(spacing: 0) {
                Spacer()
                Button {
                    Haptics.warning()
                    onDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("删除")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(showDelete || dragOffset < 0 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            content()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .offset(x: min(0, offset + dragOffset))
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .updating($dragOffset) { value, state, _ in
                            // 只处理主要水平方向的滑动,让垂直滚动仍然可用
                            if abs(value.translation.width) > abs(value.translation.height) {
                                state = max(-buttonWidth - 20, min(0, value.translation.width + offset))
                            }
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let total = offset + value.translation.width
                            withAnimation(.spring(duration: 0.3)) {
                                if total < -buttonWidth / 2 {
                                    offset = -buttonWidth
                                    showDelete = true
                                } else {
                                    offset = 0
                                    showDelete = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if showDelete {
                        withAnimation(.spring(duration: 0.3)) {
                            offset = 0
                            showDelete = false
                        }
                    }
                }
        }
    }
}
