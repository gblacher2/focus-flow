## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar methods in tight loops
**Learning:** Swift `Calendar` methods (like `.component(_:from:)` and `.startOfDay(for:)`) trigger expensive ICU date math overhead. Calling them inside tight loops (like O(N) filters and grouping reductions) causes severe performance bottlenecks for large collections.
**Action:** Pre-calculate `DateInterval` boundaries outside the loop, or cache derived `DateInterval`s to take advantage of O(1) `.contains(_:)` boundary checks, effectively removing heavy Calendar operations from the critical path.
