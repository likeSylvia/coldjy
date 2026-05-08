import SwiftUI

struct LockScreen: View {
    @Bindable var lock: LockStore
    let settings: AppSettings

    @State private var passcodeInput: String = ""
    @State private var errorMessage: String?
    @State private var attemptingBiometric = false
    @State private var shake = false
    @State private var animateIcon = false
    @FocusState private var passcodeFocused: Bool

    private var showBio: Bool {
        (settings.lockMode == .biometric || settings.lockMode == .both) && LockStore.isBiometryAvailable
    }
    private var showPasscode: Bool {
        settings.lockMode == .passcode || settings.lockMode == .both
    }

    private var biometryIcon: String {
        switch LockStore.biometryTypeAvailable() {
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "faceid"
        }
    }

    var body: some View {
        ZStack {
            // 背景: 双层渐变 + 模糊光斑
            Color(.systemBackground).ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: geo.size.width * 0.9)
                        .blur(radius: 80)
                        .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.25)

                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: geo.size.width * 0.8)
                        .blur(radius: 80)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.3)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                // 锁图标 + 呼吸光晕
                ZStack {
                    Circle()
                        .fill(.tint.opacity(animateIcon ? 0.25 : 0.12))
                        .frame(width: 130, height: 130)
                        .blur(radius: 24)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateIcon)

                    Circle()
                        .frame(width: 104, height: 104)
                        .glassEffect(.regular, in: .circle)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }

                    Image(systemName: "lock.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.tint.gradient)
                        .symbolEffect(.bounce, value: attemptingBiometric)
                }

                VStack(spacing: 8) {
                    Text("cold tools")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.tint)
                        .tracking(1.5)

                    Text("已锁定")
                        .font(.largeTitle.bold())

                    Text(hintText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // 错误提示
                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(.red.opacity(0.12))
                    }
                    .offset(x: shake ? -8 : 0)
                    .animation(
                        .spring(response: 0.2, dampingFraction: 0.3).repeatCount(3, autoreverses: true),
                        value: shake
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // 解锁操作区
                VStack(spacing: 14) {
                    if showBio {
                        Button {
                            Task { await runBiometric() }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: biometryIcon)
                                    .font(.system(size: 20, weight: .semibold))
                                Text("使用 \(LockStore.biometryDisplayName)")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(.white)
                            .background {
                                Capsule()
                                    .fill(Color.accentColor.gradient)
                                    .shadow(color: .accentColor.opacity(0.3), radius: 12, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(attemptingBiometric)
                        .opacity(attemptingBiometric ? 0.6 : 1)
                    }

                    if showPasscode {
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            SecureField("访问密码", text: $passcodeInput)
                                .keyboardType(.numberPad)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .onSubmit { submitPasscode() }
                                .focused($passcodeFocused)
                                .font(.system(size: 17, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .glassEffect(.regular, in: .capsule)

                        if !passcodeInput.isEmpty {
                            Button {
                                submitPasscode()
                            } label: {
                                Text("解锁")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .foregroundStyle(.primary)
                                    .glassEffect(.regular, in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal, 32)
                .animation(.smooth(duration: 0.25), value: passcodeInput.isEmpty)
            }
            .padding(.bottom, 50)
        }
        .onAppear {
            animateIcon = true
        }
        .task {
            if showBio {
                await runBiometric()
            }
        }
    }

    private var hintText: String {
        if showBio && showPasscode { return "使用 \(LockStore.biometryDisplayName) 或密码解锁" }
        if showBio { return "使用 \(LockStore.biometryDisplayName) 解锁" }
        if showPasscode { return "输入访问密码解锁" }
        return "请在设置中选择解锁方式"
    }

    private func runBiometric() async {
        guard !attemptingBiometric else { return }
        attemptingBiometric = true
        defer { attemptingBiometric = false }
        let ok = await lock.authenticateBiometric()
        if !ok && settings.lockMode == .biometric {
            withAnimation(.spring(duration: 0.3)) {
                errorMessage = "\(LockStore.biometryDisplayName) 验证未通过"
            }
            // 3 秒后自动消失
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                withAnimation { errorMessage = nil }
            }
        } else if !ok && settings.lockMode == .both {
            // Face ID 失败,焦点到密码框
            passcodeFocused = true
        }
        if ok { Haptics.success() }
    }

    private func submitPasscode() {
        if lock.verifyPasscode(passcodeInput, settings: settings) {
            passcodeInput = ""
            errorMessage = nil
            passcodeFocused = false
            Haptics.success()
        } else {
            Haptics.error()
            shake.toggle()
            withAnimation(.spring(duration: 0.3)) {
                errorMessage = "密码不正确"
            }
            // 清空输入重试
            passcodeInput = ""
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                withAnimation { errorMessage = nil }
            }
        }
    }
}
