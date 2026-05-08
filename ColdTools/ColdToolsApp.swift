import SwiftUI
import SwiftData

/// Schema 版本号：任何时候改了 @Model 字段就递增这个数字。
/// 启动时若检测到不匹配，主动清理旧 store 重新建库，避免旧数据库 schema 不兼容导致的崩溃。
private let kSchemaVersion = 2
private let kSchemaVersionKey = "coldtools.schema.version"

@main
struct ColdToolsApp: App {
    let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        container = Self.makeContainer()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            SmokingLog.self,
            CravingLog.self,
            WaterLog.self,
            HealthLog.self,
            WorkLog.self,
            MemoNote.self,
            AppSettings.self,
            UnlockedAchievement.self,
            UsageMarker.self,
        ])

        // 版本不匹配 -> 主动清理所有 SwiftData 持久化文件
        let savedVersion = UserDefaults.standard.integer(forKey: kSchemaVersionKey)
        if savedVersion != kSchemaVersion {
            Self.nukeAllSwiftDataStores()
            UserDefaults.standard.set(kSchemaVersion, forKey: kSchemaVersionKey)
        }

        // 使用最小参数配置,让 SwiftData 用默认路径
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            return c
        }

        // 打开失败,再清一次重试
        Self.nukeAllSwiftDataStores()
        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            return c
        }

        // 最后兜底:内存
        let memoryConfig = ModelConfiguration(
            "ColdToolsMemory",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        if let c = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
            return c
        }

        return try! ModelContainer(for: schema)
    }

    /// 扫 App 沙盒里所有可能的 SwiftData 文件并删除
    static func nukeAllSwiftDataStores() {
        let fm = FileManager.default
        var dirs: [URL] = []

        // Documents
        if let url = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            dirs.append(url)
        }
        // Application Support
        if let url = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            dirs.append(url)
        }
        // Library
        if let url = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
            dirs.append(url)
            // Library/Caches 也扫
            dirs.append(url.appendingPathComponent("Caches"))
            // Library/Private Documents
            dirs.append(url.appendingPathComponent("Private Documents"))
        }

        let extensions: Set<String> = ["store", "store-wal", "store-shm", "store-journal", "sqlite", "sqlite-wal", "sqlite-shm"]

        for dir in dirs {
            guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            while let url = enumerator.nextObject() as? URL {
                let ext = url.pathExtension.lowercased()
                let name = url.lastPathComponent.lowercased()
                if extensions.contains(ext)
                    || name.hasPrefix("default.store")
                    || name.hasPrefix("coldtools")
                    || name.contains(".sqlite") {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
