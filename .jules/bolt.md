## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-09-09 - Swift Calendar Performance Anti-Pattern
**Learning:** Avoid using `Calendar` methods like `.component(_:from:)` or `.isDate(_:inSameDayAs:)` inside tight loops (like filtering records), as they cause severe performance bottlenecks due to ICU date math overhead. Pre-calculate `DateInterval`s instead for O(1) checking using the modern `calendar.dateInterval(of:for:)` API to safely avoid Daylight Saving Time bugs.
**Action:** When filtering or bucketing dates in Swift, compute the target `DateInterval` once before the loop and use `interval.contains(date)` inside the loop.
