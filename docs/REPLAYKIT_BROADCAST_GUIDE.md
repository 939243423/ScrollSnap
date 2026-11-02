# ReplayKit 滚动录屏长截图开发指南 (ReplayKit Broadcast Guide)

本文档阐述如何通过 iOS ReplayKit Broadcast Upload Extension 实现跨应用滚屏长截图，以及如何严格遵守系统 50MB 内存红线。

---

## 1. 业务流程与交互机制

iOS 无法在未经用户明确授权的情况下跨应用捕获屏幕内容。最佳原生方案为接入 `ReplayKit` 广播扩展体系：

1. **唤起广播选择器**：主应用内提供 `RPSystemBroadcastPickerView`，轻触弹出系统级录屏宿主选择浮层。
2. **切入目标 App 并滚屏**：用户切换至微信、Safari 或任意第三方应用，匀速向下滑动屏幕。
3. **扩展逐帧捕获与降频去重**：`SampleHandler` 拦截屏幕像素缓冲区，识别滑动位移，筛选关键切片并写入 App Group。
4. **结束录制并自动拉起拼接**：点击系统状态栏红点停止录屏，主应用感知 Darwin Notification 立即加载完成长截屏。

---

## 2. 50MB 内存红线与防崩溃工程标准

iOS 对 Broadcast Upload Extension 施加严苛的 Jetsam 内存监控，驻留内存超过 **50MB** 会立即被系统终止（EXC_RESOURCE RESOURCE_TYPE_MEMORY）。

### 2.1 降频抽帧与降采样 (Frame Throttling)
iPhone 屏幕以 60Hz 或 120Hz 刷新，若逐帧处理高画质 CVPixelBuffer（`1179 x 2556 x 4` 字节 ≈ 12MB 单帧未压缩），保留 3 帧即可导致内存暴涨。

- **抽帧频率**：每秒最多处理 8~10 帧，足以覆盖高速滑动重叠率需求。
- **计算下采样**：位移测定使用 0.25x 缩小版单色灰度缓冲，单帧仅占用约 180KB 内存。

### 2.2 即时释放与磁盘流式缓冲
严禁在内存中维护 `[UIImage]` 数组。提取关键帧后，立即压缩并写入共享磁盘：

```swift
// 关键帧写入 App Group 磁盘，释放内存引用
guard let jpegData = autoreleasepool(invoking: { () -> Data? in
    guard let cgImage = self.createCGImage(from: pixelBuffer) else { return nil }
    let uiImage = UIImage(cgImage: cgImage)
    return uiImage.jpegData(compressionQuality: 0.85)
}) else { return }

try? jpegData.write(to: sliceFileURL, options: .atomic)
```

---

## 3. `SampleHandler` 核心实现骨架

```swift
import ReplayKit
import CoreMedia

public final class SampleHandler: RPBroadcastSampleHandler {
    private let frameProcessor = BroadcastFrameProcessor()
    private var isRecording = false

    public override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        isRecording = true
        SharedStore.shared.resetActiveBroadcastSession()
        CrossProcessNotifier.post(name: CrossProcessNotifier.sessionUpdatedNotification)
    }

    public override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard isRecording, sampleBufferType == .video else { return }
        
        // 使用 autoreleasepool 保证每帧局部临时对象立即析构
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            frameProcessor.process(pixelBuffer: pixelBuffer)
        }
    }

    public override func broadcastFinished() {
        isRecording = false
        frameProcessor.finalizeSession()
        CrossProcessNotifier.post(name: CrossProcessNotifier.sessionCompletedNotification)
    }
}
```
