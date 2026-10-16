## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2026-08-29 - Pre-calculate DateInterval for tight loops
**Learning:** Performance Anti-Pattern (Swift): Using `Calendar` methods (like `.component(_:from:)` or `isDate(_:inSameDayAs:)`) inside tight loops (like `Array.filter`) causes severe performance bottlenecks due to ICU date math overhead.
**Action:** Always pre-calculate `DateInterval`s before loops using `calendar.dateInterval(of: .[component], for: date)` and use `interval.contains(date)` for O(1) checks. Avoid hardcoding durations (like 86400s) to prevent DST bugs.
