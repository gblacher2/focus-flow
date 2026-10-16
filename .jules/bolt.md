## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Pre-calculate DateInterval for tight loop checks
**Learning:** Swift's `Calendar` methods (like `.component(_:from:)` or `.isDate(_:inSameDayAs:)`) cause severe performance bottlenecks inside tight loops because of ICU date math overhead.
**Action:** Avoid using `Calendar` checks within `filter` blocks or tight loops. Instead, pre-calculate a `DateInterval` for the period in question before the loop, and use `DateInterval.contains(_:)` for O(1) checking.
