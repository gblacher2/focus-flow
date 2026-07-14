## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-05-18 - Calendar Methods in Swift Loops | Performance Anti-Pattern
**Learning:** Using `Calendar` methods (like `.component(_:from:)` or `.isDate(...)`) inside tight loops in Swift causes severe performance bottlenecks due to the heavy overhead of ICU date math underneath.
**Action:** Always pre-calculate `DateInterval`s (using methods like `.dateInterval(of:for:)`) outside of loops and use `.contains(_:)` for O(1) checks when filtering collections of dates.
