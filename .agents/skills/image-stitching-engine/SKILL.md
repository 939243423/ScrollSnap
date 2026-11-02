---
name: image-stitching-engine
description: Technical instructions and optimization guidelines for iOS continuous image stitching, ReplayKit broadcast frame analysis, overlap correlation, and memory-safe ultra-long canvas rendering.
metadata:
  trigger: Working on image alignment, ReplayKit broadcast frame buffers, seam carving, long canvas tiling, and PhotoKit screenshot ingestion
---

# Image Stitching Engine Skill

Guide for developing, tuning, and debugging the iOS continuous image stitching pipeline in `ScrollSnap`.

## 1. Frame Acquisition Pipelines

### A. Photo Library Ingestion (Batch Stitching)
1. Query `PHAsset.fetchAssets(with: .image, options:)` filtered by `creationDate` within a sliding time window (e.g., 60 seconds).
2. Filter for screenshot aspect ratios matching current device screen geometry (`UIScreen.main.bounds.size`).
3. Sort chronologically by `creationDate.ascending`.

### B. ReplayKit Broadcast Ingestion (Live Rolling Capture)
1. Intercept `CMSampleBuffer` in `RPBroadcastSampleHandler.processSampleBuffer(_:with:)`.
2. Extract `CVPixelBuffer` and calculate a 1D luminance projection histogram across horizontal scanlines.
3. Compare against the previous frame. If Euclidean delta `< 0.03`, discard frame (screen hasn't scrolled).
4. If downward displacement is detected, pass candidate frame to the overlap tracker and write compressed JPEG slice to App Group shared directory (`group.com.scrollsnap`).
5. Release `CVPixelBuffer` immediately to prevent exceeding the 50MB resident memory cap.

## 2. Overlap Calculation Algorithm

### Normalized Cross-Correlation (NCC)
Given slice $A$ (top) and slice $B$ (bottom):
1. Crop the bottom search zone of slice $A$: $H_{search} = [0.2 \times H_A, 0.9 \times H_A]$.
2. Slide template window from the top of slice $B$ ($H_{template} = 120\text{ pt}$ height).
3. Compute normalized cross-correlation:
   $$R(y) = \frac{\sum (A_{sub}(x, y) - \bar{A}) (B_{tpl}(x, y) - \bar{B})}{\sqrt{\sum (A_{sub}(x, y) - \bar{A})^2 \sum (B_{tpl}(x, y) - \bar{B})^2}}$$
4. Determine peak offset $y^*$ maximizing $R(y)$. If $R(y^*) \ge 0.84$, accept alignment offset.

### Optimal Seam Line Selection
1. Avoid splitting text lines or icon strokes.
2. Search a $\pm 16\text{ pt}$ neighborhood around $y^*$ for the horizontal row with minimum variance in horizontal gradient energy:
   $$E(y) = \sum_{x} \left| \frac{\partial I}{\partial x}(x, y) \right|$$
3. Slice $A$ is clipped at this seam, and slice $B$ is merged immediately below.

## 3. High-Resolution Canvas Memory Safeguards

- For canvases with height $> 4096\text{ pt}$, avoid allocating a single monolithic `UIImage` in memory during editing.
- Store the stitch result as an array of slice descriptors with offsets: `[StitchSliceDescriptor(imageURL, cropRect, verticalOffset)]`.
- In SwiftUI, render slices inside a `ScrollView` + `LazyVStack(spacing: 0)` or `CATiledLayer`.
- On final export to disk, write sequentially to a `CGImageDestination` or file-backed CoreGraphics context.
