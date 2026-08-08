## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-08 - Optimize Date Filtering in Statistics
**Learning:** Performance bottleneck identified in Swift `Calendar` methods (e.g., `calendar.component(_:from:)`). Using these inside tight loops (like array filtering) causes significant overhead due to ICU date math operations.
**Action:** Pre-calculate `DateInterval`s using modern APIs like `calendar.dateInterval(of: period, for: date)` outside of loops, and then use the `contains` method on the interval for fast O(1) comparison during iteration, reducing complexity from O(N) to O(1).
