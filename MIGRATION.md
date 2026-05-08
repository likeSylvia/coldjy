# iOS 迁移说明

这版是 Windows 浏览器可预览原型，目标是先确定功能、审美和数据字段。迁移到 Xcode 时建议使用：

- SwiftUI：界面
- SwiftData 或 Core Data：本地数据库
- LocalAuthentication：Face ID
- UserNotifications：本地通知
- CryptoKit：加密备份
- FileProtectionType.complete：本地数据库文件保护

## 模块

首页：
- 今日减量金额
- 今日吸烟进度
- 快捷记录吸烟、忍住烟瘾、喝水、备忘
- 今日时间线

戒烟：
- 正常每日烟量 baselineCigs
- 今日目标 targetCigs
- 每包价格 packPrice
- 每包根数 sticksPerPack
- 当前阶段 phase
- 目标日期 quitTargetDate
- 吸烟记录 smokingLogs
- 烟瘾/忍住记录 cravingLogs

喝水：
- 每日目标 goal
- 提醒开始 start
- 提醒结束 end
- 提醒间隔 interval
- 喝水记录 waterLogs

记录：
- healthLogs：体重、睡眠、心情、精力、身体备注
- workLogs：上班、下班、状态、工时、备注
- notes：标题、内容、标签、提醒时间、置顶、完成状态

设置：
- Face ID App 锁
- 加密导出/导入
- 开发 JSON 导出

## 数据模型草案

```swift
@Model
final class SmokingLog {
    var id: UUID
    var date: Date
    var at: Date
    var trigger: String
    var note: String
}

@Model
final class CravingLog {
    var id: UUID
    var date: Date
    var at: Date
    var trigger: String
    var intensity: Int
    var resisted: Bool
    var note: String
}

@Model
final class WaterLog {
    var id: UUID
    var date: Date
    var at: Date
    var amount: Int
}

@Model
final class HealthLog {
    var id: UUID
    var date: Date
    var createdAt: Date
    var weight: Double?
    var sleep: Double?
    var mood: String
    var energy: String
    var bodyNote: String
}

@Model
final class WorkLog {
    var id: UUID
    var date: Date
    var createdAt: Date
    var start: Date?
    var end: Date?
    var status: String
    var hours: Double?
    var note: String
}

@Model
final class MemoNote {
    var id: UUID
    var createdAt: Date
    var title: String
    var content: String
    var tag: String
    var remindAt: Date?
    var pinned: Bool
    var done: Bool
}
```

## 统计公式

```text
单根价格 = 每包价格 / 每包根数
今日少抽 = max(正常每日烟量 - 今日实际吸烟根数, 0)
今日省钱 = 今日少抽 * 单根价格
目标进度 = 今日实际吸烟根数 / 今日目标
```

## 备份格式

开发 JSON 直接保存当前状态，方便迁移和调试。

正式备份使用 `.txbak`，结构为：

```json
{
  "kind": "tx-life-encrypted-backup",
  "version": 1,
  "kdf": "PBKDF2-SHA256",
  "iterations": 120000,
  "cipher": "AES-GCM",
  "createdAt": "2026-05-06T00:00:00.000Z",
  "salt": "...",
  "iv": "...",
  "data": "..."
}
```

iOS 版可用 CryptoKit 的 AES.GCM 与 CryptoKit/PBKDF2 兼容实现替换 Web Crypto。
