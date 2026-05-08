import SwiftUI

struct LockScreen: View {
    @Bindable var lock: LockStore
    let settings: AppSettings

    @State private var passcodeInput: String = ""
    @State private var errorMessage: String?
    @State private var attemptingBiometric = false

    private var showBio: Bool {
        (settings.lockMode == .biometric || settings.lockMode == .both) && LockStore.isBiometryAvailable
    }
    private var showPasscode: Bool {
        settings.lockMode == .passcode || settings.lockMode == .both
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.tint)
                }

                VStack(spacing: 8) {
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
                        .transition(.opacity)
                }

                Spacer()

                VStack(spacing: 12) {
                    if showBio {
                        Button {
                            Task { await runBiometric() }
                        } label: {
                            Label("使用 \(LockStore.biometryDisplayName)",
                                  systemImage: LockStore.biometryTypeAvailable() == .touchID ? "touchid" : "faceid")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(attemptingBiometric)
                    }

                    if showPasscode {
                        SecureField("访问密码", text: $passcodeInput)
                            .keyboardType(.numberPad)
                            .textContentType(.password)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            submitPasscode()
                        } label: {
                            Text("解锁")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
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
            withAnimation { errorMessage = "密码不正确" }
        }
    }
}
