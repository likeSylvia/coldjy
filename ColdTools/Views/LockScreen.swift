import SwiftUI

struct LockScreen: View {
    @Bindable var lock: LockStore
    let settings: AppSettings

    @State private var passcodeInput: String = ""
    @State private var errorMessage: String?
    @State private var attemptingBiometric = false
    @State private var shake = false

    private var showBio: Bool {
        (settings.lockMode == .biometric || settings.lockMode == .both) && LockStore.isBiometryAvailable
    }
    private var showPasscode: Bool {
        settings.lockMode == .passcode || settings.lockMode == .both
    }

    var body: some View {
        ZStack {
            // 背景用系统背景 + 渐变，符合 iOS 26 氛围
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    Circle()
                        .frame(width: 100, height: 100)
                        .glassEffect(.regular, in: .circle)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.tint)
                        .symbolEffect(.pulse, options: .repeating, value: attemptingBiometric)
                }

                VStack(spacing: 10) {
                    Text("已锁定")
                        .font(.largeTitle.bold())
                    Text(hintText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .offset(x: shake ? -8 : 0)
                        .animation(.spring(duration: 0.3).repeatCount(3, autoreverses: true), value: shake)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                VStack(spacing: 14) {
                    if showBio {
                        Button {
                            Task { await runBiometric() }
                        } label: {
                            Label("使用 \(LockStore.biometryDisplayName)",
                                  systemImage: LockStore.biometryTypeAvailable() == .touchID ? "touchid" : "faceid")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .disabled(attemptingBiometric)
                    }

                    if showPasscode {
                        SecureField("访问密码", text: $passcodeInput)
                            .keyboardType(.numberPad)
                            .textContentType(.password)
                            .padding(.horizontal, 20)
                            .frame(height: 52)
                            .glassEffect(.regular, in: .capsule)

                        Button {
                            submitPasscode()
                        } label: {
                            Text("解锁")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .disabled(passcodeInput.isEmpty)
                    }
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
        .task {
            if showBio {
                await runBiometric()
            }
        }
    }

    private var hintText: String {
        if showBio && showPasscode { return "使用 \(LockStore.biometryDisplayName) 或输入密码继续" }
        if showBio { return "使用 \(LockStore.biometryDisplayName) 继续" }
        if showPasscode { return "输入访问密码继续" }
        return "请在设置中选择解锁方式"
    }

    private func runBiometric() async {
        guard !attemptingBiometric else { return }
        attemptingBiometric = true
        defer { attemptingBiometric = false }
        let ok = await lock.authenticateBiometric()
        if !ok && settings.lockMode == .biometric {
            withAnimation { errorMessage = "\(LockStore.biometryDisplayName) 验证未通过，可再次尝试" }
        }
        if ok { Haptics.success() }
    }

    private func submitPasscode() {
        if lock.verifyPasscode(passcodeInput, settings: settings) {
            passcodeInput = ""
            errorMessage = nil
            Haptics.success()
        } else {
            Haptics.error()
            shake.toggle()
            withAnimation { errorMessage = "密码不正确" }
        }
    }
}
