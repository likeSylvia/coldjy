# cold tools

一个原生 iOS 记录 App：戒烟 · 喝水 · 健康 · 上班 · 备忘。

## 技术栈

- SwiftUI + SwiftData (iOS 17+)
- 图表：Swift Charts
- 认证：LocalAuthentication (Face ID / Touch ID)
- 通知：UserNotifications
- 备份加密：CryptoKit (AES-GCM + PBKDF2-SHA256)
- 工程生成：XcodeGen（CI 从 `project.yml` 生成 `.xcodeproj`）

## 打包 IPA（零 Mac 方案）

流程：**GitHub 推代码 → GitHub Actions 云端编译 → 下载 ipa → 爱思助手签名 → 装机**

### 1. 推代码到 GitHub

首次：

```bash
git init
git add .
git commit -m "init cold tools"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

以后每次：

```bash
git add .
git commit -m "update"
git push
```

推送后 Actions 会自动编译。也可以去仓库 **Actions** → **Build iOS IPA (unsigned)** → **Run workflow** 手动触发。

### 2. 下载 IPA

Actions 运行结束后：
1. 点进运行详情页
2. 页面最底部 **Artifacts** → 下载 `ColdTools-unsigned-ipa`
3. 解压得到 `ColdTools-unsigned.ipa`

### 3. 爱思助手签名安装

1. Windows 端打开爱思助手
2. iPhone 数据线连接并信任设备
3. 工具箱 → **IPA 签名**
4. 添加刚下载的 `.ipa`
5. **自签名**（输入 Apple ID 和密码，免费账号即可）
6. 签名成功 → **安装到设备**
7. iPhone：**设置 → 通用 → VPN 与设备管理 → 信任证书**
8. **设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机**

## 本地开发（可选）

需要 Mac。`xcodegen generate` 产生 Xcode 工程，然后用 Xcode 打开 `ColdTools.xcodeproj` 运行。

## 目录

```
ColdTools/
  ColdToolsApp.swift          # App 入口
  Info.plist
  Assets.xcassets/            # 颜色 / AppIcon（CI 生成）
  Models/                     # SwiftData 模型
  Stores/                     # 锁 / 通知等跨视图状态
  Utils/                      # 格式化 / 加密 / 日期
  Views/
    RootView.swift            # TabView + 锁屏遮罩
    LockScreen.swift          # Face ID + 密码解锁
    DashboardView.swift       # 首页
    QuitSmokingView.swift     # 戒烟
    WaterView.swift           # 喝水
    RecordsView.swift         # 记录(分段)
    HealthRecordsView.swift
    WorkRecordsView.swift
    NotesView.swift
    WeeklyReportView.swift
    SettingsView.swift        # 设置
    Components/               # 复用组件
Scripts/
  make_icon.py                # 生成 1024 AppIcon
project.yml                   # XcodeGen 工程描述
.github/workflows/build-ios.yml
```

## 常见问题

**Q: Actions 编译失败 "No such module 'XXX'"**  
可能是 Xcode 版本切换失败。workflow 里默认用 Xcode 16。如果 runner 上没有 16，会 fallback 到默认 Xcode。检查日志里 `xcodebuild -version`。

**Q: 安装上去打开一下就退出**  
确认 iPhone **开发者模式**已打开（设置 → 隐私与安全性 → 开发者模式），且在 **设备管理** 里信任了证书。

**Q: 7 天后 App 闪退**  
免费证书 7 天过期。重新下 ipa → 爱思助手重签安装。数据保留。

**Q: 我想用自己的 App 名字或 Bundle ID**  
改 `project.yml` 里的 `CFBundleDisplayName` 和 `PRODUCT_BUNDLE_IDENTIFIER`。
