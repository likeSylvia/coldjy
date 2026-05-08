import SwiftUI
import SwiftData

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

        // 首次尝试：默认磁盘存储
        let diskConfig = ModelConfiguration("ColdToolsDB", schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: [diskConfig]) {
            return c
        }

        // 旧 schema 不兼容: 删除 Application Support 下所有 SwiftData 相关文件重试
        Self.cleanupSwiftDataStores()
        if let c = try? ModelContainer(for: schema, configurations: [diskConfig]) {
            return c
        }

        // 最后兜底: 内存存储,保证能跑起来
        let memoryConfig = ModelConfiguration(
            "ColdToolsMemory",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        if let c = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
            return c
        }

        // 真的不行了,用无配置兜底(SwiftData 默认)
        return try! ModelContainer(for: schema)
    }

    static func cleanupSwiftDataStores() {
        let fm = FileManager.default
        let candidates: [URL?] = [
            try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false),
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
            fm.urls(for: .libraryDirectory, in: .userDomainMask).first
        ]
        for case let dir? in candidates {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in items {
                let name = url.lastPathComponent
                if name.contains("ColdTools") || name.hasSuffix(".store") || name.hasSuffix(".store-wal") || name.hasSuffix(".store-shm") || name == "default.store" || name.hasPrefix("default.store") {
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
