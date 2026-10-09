## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-07-09 - Avoid Calendar components in tight loops
**Learning:** Performance anti-pattern found: Calling `Calendar.component(_:from:)` or similar methods inside tight loops (like `.filter`) causes severe bottlenecks due to ICU date math overhead.
**Action:** Always pre-calculate standard intervals (like a `DateInterval` for a specific day, week, month, or year) and use `interval.contains(date)` for `O(1)` checking inside the loop instead.
