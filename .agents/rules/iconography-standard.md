# 图标与视觉符号规范 (Iconography & Anti-AI Visual Standard)

本文档定义 `ScrollSnap` 全栈代码库、界面设计、法律协议页与 Web 模拟器中的图标选用、排版符号与视觉去 AI 痕迹红线。

---

## 1. 严格禁止项 (Strict Prohibitions)

### 1.1 严禁在 UI 控件、标题与协议页中使用 Emoji 充当图标
- **禁止行为**：严禁在按钮文本、Tab 标签、卡片标题、徽章或法律政策页面中使用 Emoji 字符作为图标：
  - ❌ 禁止 `🛡️ 隐私政策`、`⚖️ 服务条款`、`📄 合规协议`、`📜 免责声明`
  - ❌ 禁止 `✨ 3D摄影棚`、`✨ 磁吸最佳`、`🚀 立即拼合`、`🎯 吸附最佳`、`🔍 2.5x 放大镜`、`🎉 保存成功`、`📋 复制长图`、`⚡ 极速对齐`
- **原因**：Emoji 是消费级聊天表情符号，跨操作系统渲染风格不一（Windows、iOS、Android 色彩与形态割裂），且为 AI 生成模板网页的最典型廉价痕迹。
- **强制替代**：
  - SwiftUI 中必须且仅使用苹果官方原生 **SF Symbols**（如 `Image(systemName: "checkmark.shield")`）。
  - HTML / Web / Markdown 协议页中必须使用 **内联单色矢量 SVG**（`stroke="currentColor" fill="none" stroke-width="1.5"`）或纯文字排版。

### 1.2 严禁泛滥使用“四角星闪烁”与“魔法棒” (Zero Gratuitous Sparkles)
- **禁止行为**：严禁在与生成式 AI 无直接关联的常规效率功能（3D 展台、机械滚轮、内购买断、导出保存）上添加 `✨`、`sparkles`、`wand.and.stars` 等玄学“魔法/AI”符号。
- **规范指引**：
  - 机械滚轮微调必须使用物理特征符号：`dial.low`、`slider.horizontal.3`、`waveform.path.ecg`。
  - 3D 摄影棚必须使用空间几何符号：`cube.transparent`、`iphone`、`camera.viewfinder`。
  - 永久买断必须使用官方凭证符号：`checkmark.seal.fill`、`cart.fill`。
  - 唯有在调用 Apple Vision 进行人脸/头像脱敏时，允许使用具体的语义符号（如 `face.dashed`、`eye.slash`）。

### 1.3 严禁 AI 模板化幻彩霓虹描边与浮夸渐变球
- **禁止行为**：严禁在卡片四周无理由添加 135° 伪流体三色高饱和渐变彩虹光晕、发光浮动星斑、或者无序的微动粒子。
- **规范指引**：遵循苹果官方原生液态玻璃（`.background(.ultraThinMaterial)` 与 `.glassBackgroundEffect`），仅依赖系统环境反射与单色微透光感。

---

## 2. 跨平台标准对应表 (Design Token Mapping)

| 业务场景 | ❌ 禁止的 AI 味表达 | ✅ SwiftUI 原生规范 (SF Symbols) | ✅ Web / HTML 矢量 SVG 规范 |
| :--- | :--- | :--- | :--- |
| **隐私安全 / 合规** | `🛡️`、`🔒` Emoji | `Image(systemName: "lock.shield")` | `<svg class="w-4 h-4 text-indigo-400" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>` |
| **法律协议 / 条款** | `📜`、`⚖️`、`📄` Emoji | `Image(systemName: "doc.text")` | `<svg class="w-4 h-4 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>` |
| **3D 摄影棚 / 带壳** | `✨ 3D`、`📸` Emoji | `Image(systemName: "cube.transparent")` | `<svg class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>` |
| **接缝磁吸 / 最佳** | `✨ 磁吸`、`🎯 最佳` | `Image(systemName: "target")` / `checkmark.circle.fill` | `<svg class="w-3.5 h-3.5 text-emerald-400" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>` |
| **放大镜 / 微距检视** | `🔍 2.5x` Emoji | `Image(systemName: "magnifyingglass")` | `<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>` |
| **复制剪贴板** | `📋 复制` Emoji | `Image(systemName: "doc.on.doc")` | `<svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>` |
| **硬件联动 / 侧键** | `⚡ 侧键`、`🚀 秒拼` | `Image(systemName: "iphone.radiowaves.left.and.right")` | `<svg class="w-4 h-4 text-blue-400" viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>` |

---

## 3. 法律合规与政策页面专用审查要求

合规中心首页 (`index.html`)、隐私政策 (`privacy.html`) 与服务条款 (`terms.html`) 必须具备与 Apple 官方法律页面同等的严肃性与专业度：
1. 页面卡片图标容器统一采用 `w-10 h-10 rounded-xl bg-slate-900 border border-white/10 flex items-center justify-center`；
2. 内部必须嵌入 100% 矢量的 Feather / Heroicons 风格单色 SVG，绝对禁止混杂任何纯文本字符 Emoji；
3. 文本行内的列表符号统一采用 `text-emerald-500` 的矢量 Checkmark SVG，严禁使用粗暴的字符 `✓` 或 `✔`。
