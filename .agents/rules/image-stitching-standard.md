# Image Stitching Engine and State Machine Specification

This rule governs the algorithm pipeline, memory ceilings, state machines, and concurrency safety for long screenshot capture, continuous frame alignment, and multi-image stitching.

## 1. ReplayKit Broadcast Extension 50MB Memory Ceiling

ReplayKit Broadcast Upload Extensions are strictly terminated by the iOS Jetsam supervisor when resident memory usage exceeds 50MB.

### Memory Guard Protocol
- **Immediate Buffer Recycling**: Do not retain incoming `CMSampleBuffer` or underlying `CVPixelBuffer` across runloop cycles. Release pixel locks immediately after feature extraction.
- **Dynamic Downsampling**: Frame comparison for overlap search must operate on 0.25x or 0.33x downsampled luminance buffers (grayscale `vImage_Buffer` or 160-point thumbnail strips) rather than full 3x retina frame buffers.
- **Disk Streaming**: When a keyframe is validated, compress it to JPEG/HEIC on disk in the shared App Group directory immediately, instead of buffering uncompressed raw bitmaps in memory.
- **Hard Memory Limit**: Keep the extension resident memory below 32MB at all times.

## 2. Monotonic Scrolling Velocity Gate (Anti-Jitter)

Screen recording capture requires strict unidirectional continuity (typically downward scrolling):
- **Upward Scroll Rejection**: Reverse scrolling movements (negative vertical delta exceeding 15 points) must be discarded. Do not append frames during rollback.
- **Stationary Threshold**: Consecutive frames with vertical displacement `< 4 points` are classified as stationary and filtered out to prevent redundant duplicate slices.
- **Velocity Clamping**: Consecutive frames with calculated displacement `> 90% frame height` indicate fast flick/jump gestures. Flag potential missing content and widen the correlation search window.

## 3. Normalized Cross-Correlation (NCC) & Overlap Bounds

- **Search Range**: Restrict template matching to the vertical window between `15%` and `85%` of the preceding slice height.
- **Correlation Confidence Threshold**:
  - Accept match when normalized correlation coefficient `r >= 0.84`.
  - When `0.70 <= r < 0.84`, verify with edge projection gradient checks across horizontal scanlines.
  - When `r < 0.70`, transition the state machine to `alignmentUncertain` and display an interactive seam fine-tuner to the user.
- **Duplicate Removal & Seam Selection**: Cut horizontal seams along scanlines with minimum luminance variance (content-neutral rows) to prevent text stroke splitting.

## 4. Ultra-Long Canvas Rendering & GPU Memory Redlines

iOS graphics pipeline fails (blank display or memory crash) when rendering single continuous bitmaps exceeding GPU texture dimensions (`8192 x 8192` or `16384 x 16384` points).

### Multi-Resolution Tiling Strategy
- **Interactive Editing Canvas**: Display long images via virtualized lazy vertical stacks (`LazyVStack`) or `CATiledLayer`, chunked into `1024 x 1024` pt display tiles.
- **Proxy Representation**: Interactive transforms (cropping, mosaic brushing, frame mockup overlays) operate on a 0.5x screen-fit proxy image.
- **Lossless Stream Export**: Full-resolution image export must use `CGImageDestination` or chunked CoreGraphics rendering directly to disk, avoiding whole-canvas single `UIImage` allocations in RAM.

## 5. Non-Destructive Privacy Redaction Protocol

- Mosaic redactions, blackouts, and highlight markings must be recorded as coordinate relative vector shapes (`NormalizedRect: (x, y, width, height)` mapped to slice indices).
- Original source slice pixels remain unmutated until the user triggers the final "Save to Photos" or "Share" action.
- Every redaction operation must support non-destructive undo and redo history tracking.

## 6. Concurrency Safety & Anti-Deadlock Rules

- **Zero Cross-Singleton Synchronous Calls**: `StitchEngine.shared`, `SharedStore.shared`, and `StoreKitManager.shared` must not invoke each other synchronously within their `init()` constructors.
- **Background Dispatch for Heavy Computations**: Feature detection, NCC cross-correlation, and image compression must execute on `DispatchQueue(label: "com.scrollsnap.stitch.engine", qos: .userInitiated)` or isolated Swift actors.
- **UI State Marshalling**: Canvas geometry, slice ordering, and progress indicators must be strictly mutated on the `@MainActor`.
