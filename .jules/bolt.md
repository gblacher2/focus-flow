## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar methods in tight loops
**Learning:** Performance Anti-Pattern (Swift) found: Avoid using `Calendar` methods (like `.component(_:from:)`) inside tight loops like `.filter`, as they cause severe performance bottlenecks due to ICU date math overhead.
**Action:** Pre-calculate `DateInterval`s based on the target period before the loop and use the O(1) `interval.contains(date)` check instead.
