## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-09-05 - Pre-calculate DateInterval for Date math
**Learning:** Calendar component methods (`.component(_:from:)`) are extremely expensive in Swift due to ICU bridging. Using them inside tight loops (like `.filter` over hundreds of records) causes severe performance bottlenecks.
**Action:** When filtering dates by a specific period, pre-calculate a `DateInterval` using `calendar.dateInterval(of:for:)` outside the loop, and use `interval.contains(date)` inside the loop for O(1) checks.
