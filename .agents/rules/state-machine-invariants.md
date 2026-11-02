# State Machine and Sensor Gate Invariants (Universal Rules)

This rule defines state transition boundaries, anti-flicker gates, sensor fusion criteria, and scheduling synchronization across iOS apps and extensions.

## 1. Multi-Sensor Gate Guards (物理状态多源门禁)
Physical state switching (e.g. entering recording mode, movement tracking, screen scrolling state) must combine multiple sensor feeds or timeout fallbacks:
- Never trigger state mutations based on single-frame transient sensor spikes.
- Require consecutive frame delta confirmations (e.g., 2+ continuous scrolling frames before transitioning from `.idle` to `.scrolling`).
- Provide deterministic timeout fallbacks to prevent state locking.

## 2. Anti-Flicker Monotonicity (防闪烁单调推进准则)
When a core user workflow or state machine enters the next operational phase:
- Enforce monotonic gates (e.g., `isCaptureActive`, `hasDepartedInitialOffset`).
- Discard backward rollback jitter (e.g. minor reverse scroll < 15pt) to avoid flipping states back and forth.
- Maintain single-directional timeline progression.

## 3. Scheduled Notification & Async Race Condition Defense
- Use absolute calendar triggers (`UNCalendarNotificationTrigger`) for deterministic scheduling.
- Remove obsolete tasks using deterministic identifier arrays before registering new tasks.
- Avoid asynchronous completion race conditions where an asynchronous cancel callback inadvertently clears newly scheduled notifications.
