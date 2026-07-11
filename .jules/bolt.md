## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-05-18 - Avoid Swift Foundation Object Instantiation in Loops
**Learning:** Instantiating heavy Swift foundation objects like `DateFormatter` or `ISO8601DateFormatter` inside a loop (e.g., `records.map` in CSV export) causes significant performance degradation as the data set grows.
**Action:** Always hoist formatter initialization outside of iteration loops to reuse a single instance.
