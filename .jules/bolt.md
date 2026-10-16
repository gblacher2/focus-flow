## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar component extraction in tight loops
**Learning:** Swift's `Calendar` API operations, especially `.component(_:from:)`, involve heavy ICU date math overhead and create severe bottlenecks when evaluated repeatedly inside loops (like filtering an array of sessions).
**Action:** Always prefer pre-calculating a single `DateInterval` outside the loop (using `calendar.dateInterval(of: .day, for: date)`) and leveraging `interval.contains(date)` for O(1) containment checking instead of repeated O(N) calendar math.
