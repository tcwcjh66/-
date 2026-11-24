# 天才威 · iPhone App 工程

这不是网页，是一个可以在 Xcode 里编译出 `.ipa` 安装包的原生 iOS 工程（Capacitor 7 壳 + 单页应用内容 + HealthKit 原生桥）。

Bundle ID：`com.tiancaiwei.app`
App 名称：天才威
版本：1.0.0

---

## 一、最短路径（约 20 分钟，全程在 Windows 上完成）

你没有 Mac，所以用云端的 macOS 机器编译。GitHub 免费账号即可。

### 1. 注册 / 登录 GitHub
打开 https://github.com ，注册一个账号（免费）。

### 2. 新建仓库
右上角 `+` → `New repository` → 名字填 `tiancaiwei-app` → 选 **Private** → `Create repository`。

### 3. 上传工程
在新建的仓库页面点 `uploading an existing file`，把这个文件夹里的**全部内容**拖进去
（除了 `node_modules` 和 `ios/App/Pods`，本来也没有）→ 底部 `Commit changes`。

> 拖拽上传对文件夹层级支持不好，更稳的方式是用 GitHub Desktop（免费）
> 或命令行：先装 Git，然后在工程目录执行
> ```
> git init
> git add .
> git commit -m "init"
> git branch -M main
> git remote add origin https://github.com/<你的用户名>/tiancaiwei-app.git
> git push -u origin main
> ```

### 4. 让它自动编译
仓库顶部 `Actions` 标签 → 如果提示启用 Workflow，点 `I understand my workflows, go ahead and enable them`。
工作流 `Build iPhone IPA` 会自动跑（首次约 15–25 分钟，之后有缓存会快很多）。

### 5. 下载 ipa
跑完后进入这次运行 → 页面底部 `Artifacts` → 下载 `TianCaiWei-unsigned-ipa`（一个 zip）。
解压得到 `TianCaiWei-unsigned.ipa`。

---

## 二、把 ipa 装进 iPhone（Windows 即可，免费 Apple ID）

免费 Apple ID 签名的签名有效期是 **7 天**，到期要重新签一次，这是 Apple 的规则。

### 1. 装签名工具
Windows 上装 **Sideloadly**：https://sideloadly.io

### 2. 装 iTunes 驱动
Sideloadly 依赖 Apple 的驱动，从 Microsoft Store 装 **iTunes**（或 iCloud）即可，不需要登录 iTunes。

### 3. 装 App
1. iPhone 用数据线连电脑，手机上点「信任此电脑」。
2. 打开 Sideloadly，把 `TianCaiWei-unsigned.ipa` 拖进去。
3. `Apple ID` 填你的 Apple ID，`Password` 填密码（如果开了双重认证，用 App 专用密码，在 appleid.apple.com 生成）。
4. 点 `Start`，等进度走完。

### 4. 手机上放行
设置 → 通用 → VPN 与设备管理 → 开发者 App → 点你的 Apple ID → 信任。

### 5. 首次打开
如果提示「不受信任的开发者」，回上一步确认信任；iOS 17/18 还可能要
设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启手机。

---

## 三、关于你要的同步功能（必须说清楚）

| 需求 | 现状 | 原因 / 怎么做 |
|---|---|---|
| **Apple Watch 数据** | 已接入，需正式签名 | 手表的心率/HRV/步数/活动能量本来就写进 Apple 健康，App 从 HealthKit 读，**不需要单独的手表 App**。但 HealthKit 能力免费签名不给。 |
| **Apple 健康（HealthKit）** | 代码已写好 | 需要 $99/年开发者账号，在 Xcode 里给 target 勾上 HealthKit 能力，重新出包。免费签名会直接拒绝授权。 |
| **微信** | 只能“分享” | 微信不开放运动/健康数据接口。App 内可以把训练卡片、饮食日报通过系统分享面板发到微信（微信会出现在分享列表里），但不能读微信运动的数据。 |
| **Keep** | 只能间接 | Keep 没有公开 API。如果 Keep 把训练记录写进了 Apple 健康，我们可以从 HealthKit 读到并标出来源；反方向（我们写进 Keep）做不到。 |

### 开通 HealthKit 的两步（等你决定上 $99 账号时）

1. 在 Xcode 中打开 `ios/App/App.xcworkspace` → target `App` → `Signing & Capabilities` → `+ Capability` → 选 **HealthKit**。
2. 重新 Archive 出包、重新安装。App 里「生物感知 → 设备与数据同步」点“授权并同步”即可。

代码已经全部就位（`ios/App/App/AppDelegate.swift` 里的 `HealthBridgePlugin`），开通 capability 后无需改任何代码。

---

## 四、改内容怎么更新

界面与功能都在 `www/index.html` 这一个文件里（样式、脚本、图片已全部内联，可离线运行）。
改完后执行：

```
npx cap copy ios
npx cap sync ios
python3 scripts/postsync.py
```

然后重新 push 触发云构建即可。

---

## 五、目录说明

```
www/index.html              ← App 的全部界面与逻辑（内联单文件）
www/icon-1024.png           ← 图标源图
ios/App/App/AppDelegate.swift ← 含 HealthKit 原生桥 HealthBridgePlugin
ios/App/App/Info.plist      ← 相机/相册/健康权限说明、竖屏、arm64
ios/App/App/Assets.xcassets/AppIcon.appiconset ← 双态图标（浅色 + 深色）
scripts/postsync.py         ← 注册原生插件到 Capacitor 配置
.github/workflows/build-ipa.yml ← 云构建脚本（出未签名 ipa）
capacitor.config.json       ← Bundle ID / 名称 / 状态栏
```

---

## 六、常见编译失败

| 报错 | 处理 |
|---|---|
| `pod install` 失败 | 重跑一次 Actions（网络抖动）；或把 Podfile 的 `platform :ios` 改成 `15.0` |
| `No signing certificate` | 正常工作流里已经 `CODE_SIGNING_ALLOWED=NO`，若你本地 Xcode 编译才需要处理 |
| 上传后 Actions 不触发 | 检查 `.github/workflows/build-ipa.yml` 是否在仓库根目录下 |
| 装完闪退 | 多半是 7 天签名过期，重新用 Sideloadly 签一次 |
