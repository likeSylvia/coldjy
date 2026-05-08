import Foundation
import LocalAuthentication
import Observation

@Observable
final class LockStore {
    enum LockState {
        case unlocked
        case locked
    }

    private(set) var state: LockState = .unlocked
    private var lastBackgroundAt: Date?
    private let autoLockGrace: TimeInterval = 30

    // Called on app launch
    func evaluateOnLaunch(settings: AppSettings) {
        if settings.lockMode != .off {
            state = .locked
        }
    }

    // Called when app resigns active (backgrounded)
    func markBackgrounded() {
        lastBackgroundAt = .now
    }

    // Called when app becomes active
    func checkReLock(settings: AppSettings) {
        guard settings.lockMode != .off else { return }
        guard let last = lastBackgroundAt else { return }
        if Date.now.timeIntervalSince(last) > autoLockGrace {
            state = .locked
        }
    }

    func lockNow(settings: AppSettings) {
        guard settings.lockMode != .off else { return }
        state = .locked
    }

    func unlock() {
        state = .unlocked
    }

    // MARK: - Biometrics

    static func biometryTypeAvailable() -> LABiometryType {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return .none
        }
        return ctx.biometryType
    }

    static var isBiometryAvailable: Bool {
        let t = biometryTypeAvailable()
        return t == .faceID || t == .touchID || t == .opticID
    }

    static var biometryDisplayName: String {
        switch biometryTypeAvailable() {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "生物识别"
        }
    }

    func authenticateBiometric(reason: String = "验证身份以查看记录") async -> Bool {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "取消"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            return false
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if ok { unlock() }
            return ok
        } catch {
            return false
        }
    }

    // MARK: - Passcode

    func setPasscode(_ plain: String, settings: AppSettings) {
        let salt = PasscodeCrypto.randomSaltHex()
        let hash = PasscodeCrypto.hash(passcode: plain, saltHex: salt)
        settings.passcodeSalt = salt
        settings.passcodeHash = hash
    }

    func clearPasscode(settings: AppSettings) {
        settings.passcodeSalt = nil
        settings.passcodeHash = nil
    }

    func verifyPasscode(_ input: String, settings: AppSettings) -> Bool {
        guard let salt = settings.passcodeSalt, let expected = settings.passcodeHash else {
            return false
        }
        let ok = PasscodeCrypto.verify(passcode: input, saltHex: salt, expectedHashHex: expected)
        if ok { unlock() }
        return ok
    }
}
