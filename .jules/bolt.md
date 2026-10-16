## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-10-11 - Swift Calendar Performance Anti-Pattern
**Learning:** Calling `Calendar` methods (like `.component(_:from:)`) inside tight loops (like `.filter` or `.map` over large arrays) introduces severe performance bottlenecks due to the overhead of ICU date math underneath.
**Action:** Always pre-calculate derived date bounds as a `DateInterval` using `calendar.dateInterval(of:for:)` outside the loop, and use `interval.contains(date)` for O(1) checking. Never hardcode durations (like 86400 seconds) to avoid DST bugs.
