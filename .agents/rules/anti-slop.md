# Anti-Slop Engineering and Text Specification

This document sets the engineering, documentation, and communication constraints for the codebase.

## 1. Prohibited Terminology

### 1.1 Forbidden English Terms
Do not use hyperbolic buzzwords in code comments, technical documentation, commit messages, or user communications:
- `delve`
- `leverage`
- `tapestry`
- `vital`
- `robust`
- `seamless`
- `navigating`
- `furthermore`
- `in conclusion`

### 1.2 Forbidden Chinese Terms
Do not use generic marketing cliches and formulaic filler words:
- `值得注意的是`
- `此外`
- `深入探究`
- `赋能`
- `打造`
- `重磅`
- `闭环`
- `矩阵`
- `痛点`
- `毋庸置疑`
- `不仅...而且...`
- `总而言之`
- `助力`
- `护航`
- `大显身手`

### 1.3 Forbidden Declarative Openings
Do not use throat-clearing speech starters:
- "Here's the thing:"
- "众所周知的是"
- "简单来说"
- "正如我们所见"

## 2. Concrete Action Verbs
Replace abstract fluff with explicit engineering operations:
- Instead of "empowering seamless stitching", state: `calculate overlap offset and blend slice edges`.
- Instead of "robust memory protection", state: `downsample frame buffers to stay within the 50MB ReplayKit limit`.
- Instead of "navigating user photos", state: `query PHFetchResult filtered by creationDate within 60-second window`.

## 3. Clickable File References
Reference source files, symbols, and documentation using Markdown links formatted with the `file://` scheme and forward slashes:
- `[StitchEngine.swift](file:///Shared/Engine/StitchEngine.swift)`
- `[SharedStore.swift](file:///Shared/Services/SharedStore.swift)`
- `[SampleHandler.swift](file:///ScrollSnapBroadcast/SampleHandler.swift)`

## 4. Documentation Density
- State technical constraints, memory ceilings, coordinate transformations, and thread boundaries directly.
- Avoid promotional prose.
- Present API contracts, state transitions, and edge-case handling with measurable values (bytes, milliseconds, points, pixel ratios).

## 5. Commit & Auto-Commit Rules
- 每次完成代码修改并通过编译验证后，必须自动执行 `git add`、`git commit` 与 `git push` 提交代码，无需等待用户额外催促。
- 每次执行 `git pull` 拉取远端更新后，必须立即执行 `xcodebuild` 验证构建是否通过；如存在合并产生的重复声明或编译错误，立即修复并推送。
- 严禁空洞赞美与夸张修饰（如 `feat: leverage advanced AI to empower seamless capture`）。
- 采用祈使句，说明修改了什么与原因（如 `feat(stitching): calculate overlap offset and eliminate repeating status bars`）。
