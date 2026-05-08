# 日常戒烟记录

PWA + Capacitor iOS 版的戒烟、喝水、健康记录 App。

## 本地预览

直接用浏览器打开 `index.html` 即可,或者用任何静态服务器:

```bash
npx serve .
# 或 python -m http.server 8000
```

## 打包 iOS App（零 Mac 方案）

用 GitHub Actions 云端编译,本地爱思助手签名。

### 一、首次推送到 GitHub

```bash
git init
git add .
git commit -m "init"
# 到 GitHub 新建一个仓库,比如叫 tx-quit-smoking
git remote add origin https://github.com/你的用户名/tx-quit-smoking.git
git branch -M main
git push -u origin main
```

### 二、触发云端编译

有两种方式:

**方式 A：推送代码自动触发**（改了 app.js/html/css 会自动编）
```bash
git add .
git commit -m "update"
git push
```

**方式 B：手动触发**
1. 打开 GitHub 仓库页面
2. 点 **Actions** 标签页
3. 左侧选 **Build iOS IPA (unsigned)**
4. 右上角 **Run workflow** → 选 main 分支 → 点绿色按钮

### 三、下载 ipa

编译完成后(约 5-10 分钟):
1. Actions 页面点开那次运行
2. 最下面 **Artifacts** 区块
3. 下载 `tx-quit-smoking-unsigned-ipa.zip`
4. 解压得到 `tx-quit-smoking-unsigned.ipa`

### 四、爱思助手签名安装

1. Windows 上打开爱思助手
2. iPhone 用数据线连接
3. 工具箱 → **IPA 签名**
4. 添加刚下载的 `.ipa`
5. **自签** → 输入 Apple ID 和密码(免费账号即可)
6. 签名成功后点 **安装到设备**
7. iPhone 上: 设置 → 通用 → VPN与设备管理 → 信任证书

### 五、后续更新

改完代码:

```bash
git add .
git commit -m "update"
git push
```

等几分钟 → 下载新 ipa → 爱思助手重新签名安装。数据不会丢。

## 注意

- 免费 Apple ID 签名的 App **7 天会过期**,过期后爱思助手重新签名安装即可,localStorage 数据保留。
- 想要不过期,要么买 Apple 开发者账号(¥688/年,1 年证书),要么走 PWA 路线(添加到主屏幕)。
- GitHub 公开仓库的 Actions macOS runner 每月 2000 分钟免费,私有仓库 200 分钟。这个项目每次编译约 5-8 分钟。

## 其他文档

- `BUILD-IOS.md` - 租云 Mac 手动打包的备用方案
- `MIGRATION.md` - 迁移到原生 SwiftUI 的数据模型和字段说明
