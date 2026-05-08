# 云 Mac 构建完整步骤（复制粘贴即可）

## 第一步：租云 Mac 后的环境准备

登录云 Mac 后打开终端（Terminal），依次执行：

```bash
# 1. 确认 Xcode 已安装（云 Mac 一般预装了）
xcode-select --install 2>/dev/null; xcodebuild -version

# 2. 安装 Node.js（如果没有的话）
# 检查是否已有：
node -v
# 如果没有，用 brew 装：
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install node

# 3. 安装 CocoaPods（Capacitor iOS 插件需要）
sudo gem install cocoapods
```

---

## 第二步：上传项目文件

把你 Windows 上 `tx` 文件夹里的这些文件传到云 Mac：

```
app.js
index.html
styles.css
manifest.json
sw.js
package.json
capacitor.config.json
icon-192.png    （用 generate-icons.html 生成）
icon-512.png    （用 generate-icons.html 生成）
```

上传方式（任选一种）：
- **方式A**：云 Mac 网页控制台一般有"上传文件"按钮
- **方式B**：先推到 GitHub，云 Mac 上 `git clone`
- **方式C**：用在线网盘中转

假设你把文件放在了 `~/Desktop/tx/`

---

## 第三步：一键构建（核心步骤）

打开终端，逐行执行：

```bash
# 进入项目目录
cd ~/Desktop/tx

# 安装 npm 依赖
npm install

# 创建 www 目录（Capacitor 读取 web 资源的地方）
mkdir -p www

# 把你的网页文件复制到 www
cp index.html styles.css app.js manifest.json sw.js www/
cp icon-192.png icon-512.png www/ 2>/dev/null

# 添加 iOS 平台
npx cap add ios

# 同步 web 资源到 iOS 项目
npx cap sync ios
```

---

## 第四步：配置 Face ID 权限

```bash
# 用命令行直接写入 Info.plist
/usr/libexec/PlistBuddy -c "Add :NSFaceIDUsageDescription string '使用 Face ID 保护你的戒烟记录'" ios/App/App/Info.plist
```

---

## 第五步：打开 Xcode

```bash
npx cap open ios
```

Xcode 会自动打开。然后在 Xcode 里操作：

### 5.1 设置签名
1. 左侧文件列表点击最顶部的 **App**（蓝色图标）
2. 中间面板选 **Signing & Capabilities** 标签
3. **Team** 下拉选你的 Apple ID（第一次需要登录：Xcode → Settings → Accounts → 添加 Apple ID）
4. **Bundle Identifier** 确认是 `com.tx.quitsmoking`
5. 如果出现红色错误，把 Bundle Identifier 改成独一无二的，比如 `com.yourname.quitsmoking`

### 5.2 设置最低版本
1. 还是在 App 项目设置里
2. **Minimum Deployments** 设为 iOS 16.0（支持你手机的系统版本即可）

### 5.3 设置 App 图标（可选）
1. 左侧找到 `App/App/Assets.xcassets/AppIcon`
2. 拖入一张 1024x1024 的图标图片

---

## 第六步：编译导出 .ipa

### 方法 A：直接 Archive 导出（推荐）

1. Xcode 顶部设备选择器选 **Any iOS Device (arm64)**
2. 菜单栏 → **Product** → **Archive**（等待编译，约 1-3 分钟）
3. 编译完成后弹出 Organizer 窗口
4. 选中刚才的 Archive → 点右边 **Distribute App**
5. 选 **Custom** → **Development** → 下一步到底 → **Export**
6. 选一个保存位置，得到一个文件夹，里面有 `.ipa` 文件

### 方法 B：命令行导出（如果 Xcode GUI 卡）

```bash
cd ~/Desktop/tx/ios/App

# 编译 Archive
xcodebuild -workspace App.xcworkspace \
  -scheme App \
  -configuration Release \
  -archivePath ~/Desktop/App.xcarchive \
  -destination "generic/platform=iOS" \
  archive

# 导出 ipa（需要先创建 ExportOptions.plist）
cat > ~/Desktop/ExportOptions.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath ~/Desktop/App.xcarchive \
  -exportPath ~/Desktop/ipa-output \
  -exportOptionsPlist ~/Desktop/ExportOptions.plist
```

导出完成后 `~/Desktop/ipa-output/` 里就有 .ipa 文件。

---

## 第七步：下载 .ipa 到 Windows

从云 Mac 把 .ipa 文件下载到你的 Windows 电脑。

---

## 第八步：爱思助手签名安装

1. Windows 上打开爱思助手
2. iPhone 用数据线连电脑
3. 爱思助手 → **工具箱** → **IPA签名**
4. 添加 .ipa 文件
5. 使用 Apple ID 签名（输入你的 Apple ID 和密码）
6. 签名完成后点 **安装到设备**
7. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任你的开发者证书

搞定，App 出现在桌面上了。

---

## 后续更新代码

改完代码后不需要重复全部步骤：

```bash
cd ~/Desktop/tx
# 复制新文件到 www
cp index.html styles.css app.js www/
# 同步到 iOS
npx cap sync ios
# 然后 Xcode 重新 Archive 导出 ipa
```

---

## 常见问题

### Q: Archive 按钮是灰色的？
设备选择器必须选 "Any iOS Device"，不能选模拟器。

### Q: 签名报错 "No signing certificate"？
Xcode → Settings → Accounts → 你的 Apple ID → 点 Manage Certificates → 左下角 + → Apple Development

### Q: 爱思助手签名失败？
- 确保 Apple ID 没开双重认证，或者生成了 App 专用密码
- 换一个没注册过开发者的 Apple ID 试试

### Q: 7 天后 App 闪退？
正常现象，免费证书 7 天过期。重新用爱思助手签名安装一次就行（不会丢数据，localStorage 还在）。

### Q: 能不能不用云 Mac？
不行。iOS App 必须在 macOS + Xcode 上编译。但你只需要租一次（构建完拿到 ipa 就可以释放），后续只有改代码时才需要再租。
