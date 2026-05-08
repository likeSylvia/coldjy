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
    var baselineCigs: Int
    var targetCigs: Int
    var packPrice: Double
    var sticksPerPack: Int
    var quitPhase: String
    var quitTargetDate: Date?

    var waterGoalML: Int
    var waterStartHour: Int
    var waterEndHour: Int
    var waterIntervalMin: Int
    var waterRemindersEnabled: Bool

    var lockModeRaw: String
    var passcodeHash: String?
    var passcodeSalt: String?

    var useSystemAppearance: Bool
    var forceDarkMode: Bool
    var themeRaw: String

    init() {
        self.baselineCigs = 20
        self.targetCigs = 12
        self.packPrice = 25
        self.sticksPerPack = 20
        self.quitPhase = "减量期"
        self.quitTargetDate = nil
        self.waterGoalML = 2000
        self.waterStartHour = 9
        self.waterEndHour = 22
        self.waterIntervalMin = 90
        self.waterRemindersEnabled = false
        self.lockModeRaw = "off"
        self.passcodeHash = nil
        self.passcodeSalt = nil
        self.useSystemAppearance = true
        self.forceDarkMode = false
        self.themeRaw = "warmAmber"
    }

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
    var code: String
    var unlockedAt: Date

    init(code: String, unlockedAt: Date = .now) {
        self.code = code
        self.unlockedAt = unlockedAt
    }
}
