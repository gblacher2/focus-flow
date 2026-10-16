## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Optimizing `Calendar` date math in Swift loops
**Learning:** Found a Swift performance anti-pattern inside `StatisticsCalculator.swift`. In tight loops (like filtering records for a chart view), using `calendar.component(_:from:)` repeatedly is slow because it causes expensive ICU date math overhead for each item.
**Action:** When filtering dates by periods (day, week, month, year) over a collection, pre-calculate the `DateInterval` outside the loop using `calendar.dateInterval(of: <component>, for: date)`. Then, use `interval.contains(item.date)` which is an O(1) mathematical bounds check. Avoid hardcoding durations (like 86400 seconds) to ensure daylight saving time correctness.
