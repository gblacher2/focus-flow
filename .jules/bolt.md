## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar math in tight loops
**Learning:** `Calendar.component` and `calendar.startOfDay` are extremely slow due to ICU date math overhead. Calling them repeatedly inside tight loops like array filter or grouping causes severe performance bottlenecks for large collections.
**Action:** Pre-calculate `DateInterval` using `calendar.dateInterval` before the loop and use `interval.contains()` for O(1) checks. For grouping, cache the interval of the last seen date to reuse it for subsequent clustered records.
