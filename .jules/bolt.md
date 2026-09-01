## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-07-09 - Avoid Calendar methods in tight loops
**Learning:** Performance Anti-Pattern (Swift) found: avoid using `Calendar` methods (like `.component(_:from:)`) inside tight loops (like `.filter` over arrays). These methods cause severe performance bottlenecks due to ICU date math overhead.
**Action:** Pre-calculate `DateInterval`s for the target period using `calendar.dateInterval(of: <component>, for: date)` before the loop, and use an `O(1)` `DateInterval.contains(_:)` check inside the loop instead.
