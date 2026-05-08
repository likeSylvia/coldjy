import SwiftUI
import UIKit

/// 点空白收起键盘
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
    }
}

extension View {
    /// 点空白收键盘 (不干扰滚动和按钮)
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }

    /// 给任意 Form / ScrollView 加"完成"工具栏
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}
