# Frontend Design Specification (Apple HIG & Native Fluid UX)

This rule defines visual layout, typography, palette, motion, and interaction standards across all SwiftUI views and App Extensions.

## 1. 8pt Spatial Grid System

All margins, paddings, gap spacings, and corner radii must adhere to the 8pt baseline scale:
- `4pt`: Micro spacing (badge internal padding, hairline dividers, icon-text gap in compact pills).
- `8pt`: Compact spacing (button vertical padding, compact row gaps).
- `12pt`: Standard content gap (subtext spacing, list item inner horizontal padding).
- `16pt`: Section gutter & standard card inner padding.
- `20pt`: Standard card corner radius, container exterior padding.
- `24pt`: Hero container corner radius, modal sheet top padding.
- `32pt`: Section divider clearance, bottom action safe area clearance.

### Corner Radii Hierarchy
- Micro badges & status tags: `6pt` or `8pt`.
- Action buttons & selector pills: `12pt` or `14pt`.
- Standard content cards: `20pt` with continuous curvature (`.continuous`).
- Modal sheets & canvas frames: `24pt` with continuous curvature (`.continuous`).

## 2. Palette and Material Translucency

Strictly avoid saturated gradients and ungrounded primary colors. Use system semantic tokens and Morandi low-saturation tones:

### Surface Hierarchies
- Main canvas background: `Color(uiColor: .systemGroupedBackground)`
- Secondary container surface: `Color(uiColor: .secondarySystemGroupedBackground)`
- Floating toolbars & inspectors: Material `.ultraThinMaterial` or `.thinMaterial`
- Card edge highlight:
  ```swift
  .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(
              LinearGradient(
                  colors: [Color.white.opacity(0.18), Color.clear],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
              ),
              lineWidth: 1
          )
  )
  ```

### Accent Palette
- Primary Action Tint: Deep Slate Indigo (`#4A5568` light / `#63B3ED` dark) or Subtle Steel Teal (`#319795`).
- Success Accent: Muted Sage Green (`#38A169`).
- Warning Accent: Warm Ochre (`#D69E2E`).
- Destructive Accent: Terracotta Red (`#E53E3E`).

## 3. Typography and Number Rendering

- Display & Headings: `Font.system(.title2, design: .rounded).weight(.semibold)`
- Body text: `Font.system(.body, design: .default)`
- Quantitative values (slice indices, dimension readouts, memory footprint, timestamps):
  - Always append `.monospacedDigit()` to prevent horizontal jitter during scrubbing or dynamic updates.
  - Example: `Text("\(Int(canvasHeight)) px").font(.caption.monospacedDigit())`

## 4. Iconography Standards

- Exclusively use Apple SF Symbols (version 4+ / 5+).
- Strictly ban emoji decorations (🚀, 🔥, ✨, 🧠, 🤖, 📱) in production user interfaces and status bars.
- Utilize hierarchical symbol rendering for dimensional depth:
  ```swift
  Image(systemName: "photo.stack.fill")
      .symbolRenderingMode(.hierarchical)
      .foregroundStyle(Color.accentColor)
  ```

## 5. Haptic Feedback Protocol

- Utilize pre-warmed `UIImpactFeedbackGenerator(style: .light)` for granular touch steps (slider steps, slice selection, toggle switches).
- Utilize `UINotificationFeedbackGenerator` for stitch completion and export success.
- Enforce a 70ms hardware debounce threshold on all drag/scrub gestures to prevent Taptic Engine buffer saturation.

## 6. Layout Composition & Information Hierarchy

- Single Context Awareness: Avoid stacking consecutive announcement banners on the home view. The primary stitch workbench and recent captures must occupy the prime view area.
- Empty states must act as direct actionable invitations (e.g., "Select Photos to Stitch" or "Start Scrolling Capture") rather than static dead ends.
