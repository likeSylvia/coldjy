import Foundation
import SwiftData

enum LockMode: String, CaseIterable, Identifiable, Codable {
    case off = "off"
    case biometric = "biometric"
    case passcode = "passcode"
    case both = "both"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .biometric: return "仅 Face ID"
        case .passcode: return "仅密码"
        case .both: return "Face ID + 密码"
        }
    }
}

@Model
final class AppSettings {
    // Smoking
    var baselineCigs: Int = 20
    var targetCigs: Int = 12
    var packPrice: Double = 25
    var sticksPerPack: Int = 20
    var quitPhase: String = "减量期"
    var quitTargetDate: Date?

    // Water
    var waterGoalML: Int = 2000
    var waterStartHour: Int = 9
    var waterEndHour: Int = 22
    var waterIntervalMin: Int = 90
    var waterRemindersEnabled: Bool = false

    // Lock
    var lockModeRaw: String = "off"
    var passcodeHash: String?   // sha256 hex
    var passcodeSalt: String?   // random bytes hex

    // UI
    var useSystemAppearance: Bool = true
    var forceDarkMode: Bool = false
    var themeRaw: String = "warmAmber"

    init() {}

    var lockMode: LockMode {
        LockMode(rawValue: lockModeRaw) ?? .off
    }

    var pricePerStick: Double {
        guard sticksPerPack > 0 else { return 0 }
        return packPrice / Double(sticksPerPack)
    }
}

@Model
final class UnlockedAchievement {
    var code: String = ""
    var unlockedAt: Date = Date.now

    init(code: String, unlockedAt: Date = .now) {
        self.code = code
        self.unlockedAt = unlockedAt
    }
}
