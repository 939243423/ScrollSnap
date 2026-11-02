---
name: frontend-design
description: Guidance for distinctive, intentional visual design when building new UI or reshaping an existing one. Helps with aesthetic direction, typography, and making choices that don't read as templated defaults.
---

# Frontend Design

Approach this as the design lead at a design studio known for giving every client a distinct visual identity that is not mistaken for anyone else's.

## Design Principles for iOS

1. **8pt Grid & Proportions**: Adhere strictly to 8pt increments (`4 / 8 / 12 / 16 / 20 / 24 / 32`). Cards use 20pt or 24pt corner radius with continuous curvature.
2. **Morandi Palette & Translucency**:
   - Utilize system background semantic colors (`systemGroupedBackground`, `secondarySystemGroupedBackground`).
   - Use `.ultraThinMaterial` for floating toolbars and navigation chrome.
   - Accent colors must use low-saturation, calm hues (e.g. slate blue, sage green, graphite).
3. **Typography**:
   - Distinctive typography using San Francisco rounded variants for numeric counters and headings.
   - Monospaced numeric alignments (`.monospacedDigit()`) for all measurement metrics and pixel coordinates.
4. **Native SF Symbols Only**:
   - Never use generic Unicode emojis (🚀, 🔥, 📱, ✨) in production UI.
   - Use Apple SF Symbols with hierarchical rendering mode (`.symbolRenderingMode(.hierarchical)`).
5. **Tactile Haptics**:
   - Trigger crisp `UIImpactFeedbackGenerator(style: .light)` for snap points and selections.
   - Maintain a 70ms hardware debounce gate on interactive gestures.
6. **Actionable Blank Canvas**:
   - Empty states must present immediate actionable entry points instead of passive decorative illustrations.
