## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar math in tight loops
**Learning:** Performance anti-pattern found: using `Calendar.component(_:from:)` or `Calendar.isDate(_:inSameDayAs:)` inside tight filtering loops (like grouping thousands of statistics records). The heavy ICU date math overhead scales `O(N)` and causes major bottlenecks.
**Action:** Pre-calculate `DateInterval`s bounds outside loops using modern APIs like `calendar.dateInterval(of: .day, for: date)`. The `DateInterval.contains(_:)` check is `O(1)` and orders of magnitude faster.
