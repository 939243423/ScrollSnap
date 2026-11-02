# 项目里程碑与测试矩阵 (Roadmap & Testing Matrix)

本文档规划 `ScrollSnap` 的研发推进阶段与真机验收场景矩阵。

---

## 1. 研发路线图 (Roadmap)

### 阶段 1：核心骨架与算法核（已就绪）
- [x] 确立 Main App + Broadcast Upload Extension + Widget Extension + Shared 代码拓扑；
- [x] 注入 `.agents/rules` 与 `.agents/skills` 体系（Anti-Slop、HIG 前端规范、拼接引擎规范）；
- [x] 构建纯端侧 `StitchEngine`，支持 1D 灰度投影与 NCC 归一化互相关匹配；
- [x] 设立跨进程数据总线 `SharedStore` 与 Darwin Notification 监听。

### 阶段 2：相册连续截图智能感知与拼合
- [x] 基于 PhotoKit 实现 60 秒内连续截屏自动聚类感知；
- [x] 接缝最小梯度能量分析与 4 像素线性羽化；
- [x] 虚拟化 `LazyVStack` 画布加载，防 8192px 纹理溢出。

### 阶段 3：ReplayKit 滚动录屏广播扩展
- [x] 落地 `SampleHandler` 与 `BroadcastFrameProcessor`；
- [x] 动态 0.25x 采样率，把控 32MB 内存红线；
- [x] 关键帧即时 JPEG 压缩写盘与跨进程通知。

### 阶段 4：高质感编辑器与带壳展台
- [x] 非破坏性马赛克与隐私信息脱敏涂抹；
- [x] 物理级 iPhone 15/16 Pro 钛金属边框带壳导出；
- [x] 70ms 防抖硬件触觉反馈引擎。

### 阶段 5：灵动岛实时活动与 StoreKit 2
- [x] `ActivityKit` 4 态（紧凑前导/后置、最小化、展开态）录制进度；
- [x] iOS 17+ `AppIntent` 免拉起交互桌面小组件；
- [x] StoreKit 2 现代异步权益监听与清晰的 Pro 会员边界。

---

## 2. 真机严苛测试矩阵 (Test Matrix)

| 测试场景 | 核心挑战 | 验收通过标准 |
|---|---|---|
| **微信聊天记录长截屏** | 头像重叠、单调绿白气泡易误判 | NCC 置信度 $\ge 0.88$，文字行距无劈开错位，吸底输入栏被正确排除 |
| **Safari 网页长图滚屏** | 动态伸缩导航栏、大面积纯色空白 | 顶底安全区自适应排除，纯白段落由投影位移兜底，无缝对齐 |
| **ReplayKit 120 帧高刷滚屏** | 50MB Jetsam 内存强杀红线 | 连续录制 120 帧，Xcode 调试仪表盘常驻内存始终保持在 26MB~31MB |
| **超长 35,000px 画布导出** | iOS GPU 纹理限制导致白屏崩溃 | 分块流式写盘，内存峰值不超过 90MB，相册保存成功且放大后字体清晰 |
| **快速连续拖拽接缝滑块** | Taptic Engine 硬件拥堵发热 | 70ms 硬件防抖生效，手感清脆克制，主线程无任何卡顿掉帧 |
