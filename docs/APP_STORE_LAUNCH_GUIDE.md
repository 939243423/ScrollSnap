# ScrollSnap 商业化冲榜与 App Store 运营上架全案指南 (App Store Launch & Growth Playbook)

> **定位**：对标 Apple Design Award 与 App Store 效率榜 Top 10 的端侧长截图效率神器。  
> **商业策略**：每日免费 2 次 + ¥1.00 永久终身买断（低决策门槛、高转化率、零订阅反感）。  
> **隐私合规**：100% 纯本地离线处理，联系邮箱：`ruohui49@gmail.com`。

---

## 一、 App Store 元数据与 ASO 关键词优化矩阵

### 1. 命名与副标题规范 (不超过 30 个中文字符)
- **App 名称 (30字符内)**：`ScrollSnap 滚动画布 - 智能长截图拼接`
- **副标题 (Subtitle, 30字符内)**：`无缝长图拼合、双目对比帘幕与3D海报直出`
- **主类别 (Primary Category)**：效率 (Productivity)
- **次类别 (Secondary Category)**：摄影与录像 (Photo & Video)

### 2. ASO 核心关键词库 (100 字符限制，英文半角逗号分隔，无空格)
```text
长截图,滚动截屏,拼长图,截长图,聊天记录截图,长截屏,网页长截图,电影台词拼接,九宫格切片,录屏转长图,无缝拼接,台词拼图,长图拼接,图片拼接,拼图
```

### 3. App Store 官方宣传文本 (Promotional Text, 170字符内，可随时修改无需发版)
> 连按截屏后轻点背面，0.3 秒无感拼好长图存入剪贴板！首创双目无缝对比帘幕与微米级机械棘轮微调，配备沙漠钛 3D 摄影棚海报直出与极光毛玻璃隐私保护。纯本地运算，每日免费 2 次，仅需 ¥1 永久买断！

### 4. 完整的应用描述 (Description, Markdown 排版结构)

```text
ScrollSnap 滚动画布 —— 专为追求极致美感与操作效率的 iPhone 用户打造的纯端侧无损长截图工具。

告别繁琐的手动对齐与粗糙的拼图软件！ScrollSnap 深度整合 iOS 原生液态玻璃材质与底层图形计算管线，带来媲美苹果第一方软件的丝滑体验。

【四大核心破局特性】
1. 双目无缝对比帘幕 (Before/After Split Curtain)
推拉高精度微光激光游标，左侧直观展现多张截屏的吸顶状态栏与重复文字，右侧展现 100% 算法无缝拼合效果，毫厘之间洞悉亚像素对齐质量。

2. 微米级机械棘轮微调旋钮 (Tactile Seam Dial)
滑动滚轮或点击步进按钮，以 0.5px 精度对切片进行实时微调，转动时伴随清脆机械齿轮震感；当微调回到最佳缝合点时，翡翠绿霓光自动磁吸锁定。

3. 3D 摄影棚海报直出 (Studio Showroom)
配备沙漠钛、原色钛、深空黑、银白钛四款苹果旗舰边框，自由旋转空间 3D 俯仰角与地面漫反射阴影，一键导出 4K 商业级社交宣传海报。

4. 极光毛玻璃“隐私刮刮乐” (Liquid Frosted Glass)
告别丑陋的黑块马赛克！借助 Apple Neural Engine 毫秒级离线识别头像与手机号，像刮刮乐一样手绘涂抹极光毛玻璃笔刷，优雅守护个人隐私。

【系统级极客联动】
• 15 Pro 操作按钮与轻点背面：连按截屏后轻按侧键或敲击手机背面，后台 0.3 秒极速拼好并自动存入系统剪贴板。
• ReplayKit 滚动录屏：从控制中心轻点录屏，滚动手势结束时自动去重并生成高清长图。
• 灵动岛实时监控：实时显示切片帧率与内存状态，守住 50MB 内存安全红线。

【极简透明的商业模式】
• 每日免费 2 次长截图拼接（每日 00:00 自动刷新）
• ¥1.00 永久终身买断（零订阅、无续费陷阱、随 Apple ID 永久恢复）

【100% 隐私承诺】
所有图像计算、NCC 互相关匹配、OCR 识别均在您设备本地完成，绝不上传云端，零追踪、零数据留存。
开发者联系邮箱：ruohui49@gmail.com
官方合规中心：https://939243423.github.io/protocol__ScrollSnap/
```

---

## 二、 智能好评引导与口碑裂变机制 (StoreReviewManager)

### 1. 评分引导的黄金法则（绝不在非恰当时机打扰用户）
根据苹果 App Store 审核指南 5.6.1，**严禁在应用启动时、崩溃后或用户刚打开应用时弹出评分**。
ScrollSnap 采用**「Aha! 巅峰体验瞬间」**智能触发机制：

- **触发时机**：
  1. 用户成功导出长截图到系统相册或完成分享后；
  2. 用户在 3D 摄影棚成功导出 4K 宣传海报后；
  3. 用户成功将切片分块为 9 宫格存入相册后。
- **频次节流控制**：
  - 至少完成 **2 次** 完美拼接后才开始首次评估；
  - 两次评分弹窗之间设置 **45 天冷冻期**；
  - 当前 App 版本内仅提醒一次，绝不重复打扰。

### 2. 口碑分流闭环机制 (Good Rating to Store, Issue to Email)
- **正面用户（获得成就感）**：直接引导至 App Store 5 星撰写好评，提升应用在榜单与自然搜索排名中的权重。
- **需要改进的用户（遇到偶发问题）**：在设置中心与导出失败时，提供一键发信到 `ruohui49@gmail.com`，自动预填设备型号、iOS 系统版本与 App Build 编号，把负面情绪在应用内转化为产品迭代动力，避免直接产生 App Store 1 星差评。

---

## 三、 全新功能提醒与版本升级日志 (WhatsNewManager)

1. **苹果规范的“全新功能”引导页 (`WhatsNewSheetView`)**：
   - 当检测到应用升级到新版本（如 v1.1.0、v1.2.0）且用户首次启动时，优雅弹出单页全功能特性卡片。
   - 包含高饱和度 Apple 原生 SF Symbols 舱、粗体标题与精炼说明，底部配有“继续使用”的液态玻璃主按钮。
2. **设置中心随时回顾**：
   - 在“设置 -> 版本更新与特性”中常驻入口，供老用户随时查阅历史迭代亮点。

---

## 四、 病毒式裂变传播水印 (ExportWatermarkManager)

1. **极简水印设计准则**：
   - 借鉴 Pixelmator、Taio、Craft 等顶尖工具的传播策略：在长截图最底部附带 54pt 高度的极简发丝线与说明 `Captured with ScrollSnap · 滚动画布`。
   - 整体色调为克制的低饱和灰色，完全不遮挡正文，反而给长图带来类似 Apple Keynote 幻灯片般的杂志质感。
2. **商业化权限分层**：
   - **免费用户**：默认开启水印，用户将长截图发到小红书、知乎、微博时，形成零成本病毒式裂变自传播。
   - **¥1.00 永久买断 Pro 用户**：享有纯净特权，可在设置中自由关闭水印，彻底移除底部签名。

---

## 五、 苹果 App Store 编辑推荐自荐信模板 (Editorial Nomination)

在应用提交审核并上线前 2~3 周，可在苹果开发者后台（[App Store Feature Nomination Form](https://developer.apple.com/app-store/promote/form/)）提交官方编辑自荐信：

```text
App Name: ScrollSnap (滚动画布)
Platform: iOS 17.0+ (Universal for iPhone & iPad)
Pricing: Free with 2 daily stitches, $0.99 / ¥1.00 Lifetime Unlock

Editorial Pitch Summary:
ScrollSnap is a high-craft, 100% on-device continuous screenshot stitching and visual studio engineered for iOS. Built from the ground up using native SwiftUI, CoreGraphics, and Apple Silicon Neural Engine, ScrollSnap introduces three groundbreaking innovations to the utilities category:

1. Before/After Split Curtain: Users can drag a micro-illuminated titanium cursor to interactively verify sub-pixel stitching seam accuracy in real time.
2. Tactile Seam Dial: Features knurled physical micro-steppers with 0.5px sub-pixel adjustments, paired with acoustic ratchet sound effects and rigid magnetic lock haptics.
3. 3D Studio Showcase: Allows users to place long screenshots inside photorealistic iPhone frames (Desert Titanium, Natural Titanium, Space Black) with dynamic 3D spatial tilt and ambient ground reflection, exporting 4K social posters with one tap.

Deep Apple Platform Integration:
• App Intents: Native integration with iPhone 15 Pro/16 Pro Action Button and Back Tap (double-tap back of iPhone to seamlessly stitch and paste into clipboard).
• Live Activities & Dynamic Island: Shows real-time broadcast ingestion frame rates and memory headroom (<50MB strict limit).
• Complete Privacy: 100% offline computation with zero tracking, adhering strictly to App Store 5.1.1.
```

---

## 六、 App Store Connect 审核人员备注指南 (Reviewer Notes)

为确保审核人员一轮通过，在 App Store Connect 的“审核备注 (Review Notes)”中附带以下说明：

```text
Dear App Store Review Team,

Thank you for reviewing ScrollSnap!

1. 100% On-Device & Privacy Architecture:
ScrollSnap does NOT require an account, has zero network dependencies for image processing, and collects zero analytics or tracking data. All stitching is performed strictly on-device using CoreGraphics.

2. In-App Purchase (StoreKit 2 Testing):
ScrollSnap provides a Lifetime Pro unlock (Tier 1, ¥1.00 / $0.99 non-consumable, Product ID: com.scrollsnap.lifetime.tier1). You may test the purchase and restore flows safely in Sandbox.

3. Testing Long Screenshot Stitching:
You can test the core stitching engine either by picking multiple overlapping screenshots from the Photos library via the "相册拼接" button, or by tapping "一键拼合" when recent continuous screenshots are detected.

4. Legal Documents & Contact:
• Privacy Policy: https://939243423.github.io/protocol__ScrollSnap/privacy.html
• Terms of Service: https://939243423.github.io/protocol__ScrollSnap/terms.html
• Developer Contact: ruohui49@gmail.com

Please feel free to contact us if you need any additional information!
```
