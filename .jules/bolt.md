## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-07-08 - Avoid Calendar math in tight loops
**Learning:** Performance anti-pattern found: using `Calendar.component(_:from:)` or `calendar.isDate(_:inSameDayAs:)` inside `.filter` loops causes severe performance bottlenecks due to expensive ICU date math overhead on every element.
**Action:** Pre-calculate `DateInterval`s outside the loop and use `interval.contains(date)` for O(1) checking.
