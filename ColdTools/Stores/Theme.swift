import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case warmAmber = "warmAmber"     // 暖琥珀（默认）
    case iceBlue = "iceBlue"         // 冰蓝
    case forestGreen = "forestGreen" // 森林绿
    case cherryPink = "cherryPink"   // 樱桃粉
    case royalPurple = "royalPurple" // 典雅紫
    case graphite = "graphite"       // 石墨灰
    case sunsetCoral = "sunsetCoral" // 日落珊瑚
    case midnight = "midnight"       // 午夜蓝

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmAmber: return "暖琥珀"
        case .iceBlue: return "冰蓝"
        case .forestGreen: return "森林"
        case .cherryPink: return "樱花"
        case .royalPurple: return "典雅紫"
        case .graphite: return "石墨"
        case .sunsetCoral: return "日落"
        case .midnight: return "午夜"
        }
    }

    /// 主色（浅色模式）
    var light: Color {
        switch self {
        case .warmAmber: return Color(red: 0.94, green: 0.55, blue: 0.18)
        case .iceBlue: return Color(red: 0.0, green: 0.48, blue: 0.9)
        case .forestGreen: return Color(red: 0.2, green: 0.6, blue: 0.35)
        case .cherryPink: return Color(red: 0.93, green: 0.35, blue: 0.55)
        case .royalPurple: return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .graphite: return Color(red: 0.35, green: 0.35, blue: 0.4)
        case .sunsetCoral: return Color(red: 0.95, green: 0.42, blue: 0.4)
        case .midnight: return Color(red: 0.15, green: 0.25, blue: 0.55)
        }
    }

    /// 主色（深色模式下稍亮，保证对比度）
    var dark: Color {
        switch self {
        case .warmAmber: return Color(red: 1.0, green: 0.72, blue: 0.4)
        case .iceBlue: return Color(red: 0.4, green: 0.72, blue: 1.0)
        case .forestGreen: return Color(red: 0.45, green: 0.82, blue: 0.55)
        case .cherryPink: return Color(red: 1.0, green: 0.55, blue: 0.72)
        case .royalPurple: return Color(red: 0.78, green: 0.58, blue: 1.0)
        case .graphite: return Color(red: 0.65, green: 0.65, blue: 0.72)
        case .sunsetCoral: return Color(red: 1.0, green: 0.62, blue: 0.55)
        case .midnight: return Color(red: 0.45, green: 0.6, blue: 0.95)
        }
    }

    /// 辅助色 - 用于次要强调
    var accent2: Color {
        switch self {
        case .warmAmber: return .orange
        case .iceBlue: return .cyan
        case .forestGreen: return .green
        case .cherryPink: return .pink
        case .royalPurple: return .purple
        case .graphite: return .gray
        case .sunsetCoral: return .red
        case .midnight: return .indigo
        }
    }
}

@Observable
final class ThemeStore {
    private(set) var theme: AppTheme
    private(set) var appearance: AppearanceMode

    enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
        case system, light, dark
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    init(theme: AppTheme = .warmAmber, appearance: AppearanceMode = .system) {
        self.theme = theme
        self.appearance = appearance
    }

    static func defaultStore() -> ThemeStore {
        ThemeStore()
    }

    func applyFrom(settings: AppSettings) {
        self.theme = AppTheme(rawValue: settings.themeRaw) ?? .warmAmber
        if settings.useSystemAppearance {
            self.appearance = .system
        } else {
            self.appearance = settings.forceDarkMode ? .dark : .light
        }
    }

    func setTheme(_ t: AppTheme, settings: AppSettings) {
        theme = t
        settings.themeRaw = t.rawValue
    }

    func setAppearance(_ a: AppearanceMode, settings: AppSettings) {
        appearance = a
        switch a {
        case .system:
            settings.useSystemAppearance = true
        case .light:
            settings.useSystemAppearance = false
            settings.forceDarkMode = false
        case .dark:
            settings.useSystemAppearance = false
            settings.forceDarkMode = true
        }
    }

    /// 当前生效的主色
    func tintColor(scheme: ColorScheme) -> Color {
        scheme == .dark ? theme.dark : theme.light
    }
}
