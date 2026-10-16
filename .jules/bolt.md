## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-01-28 - Optimize Calendar.component in loops
**Learning:** Calling `Calendar.component(_:from:)` or similar Calendar methods inside a tight loop (e.g., `filter` over thousands of records) is a severe performance bottleneck. It involves expensive ICU date math for every iteration.
**Action:** Lift the period calculation out of the loop by resolving a single `DateInterval` once, then use `DateInterval.contains(_:)` inside the loop for O(1) checking.
