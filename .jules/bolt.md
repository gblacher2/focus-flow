## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Optimize Calendar usage in tight loops
**Learning:** Found a performance bottleneck where `Calendar` methods (like `.component(_:from:)`, `.isDate(_:inSameDayAs:)`, and `.startOfDay(for:)`) were being called inside tight loops (`.filter` and `for` loops iterating over arrays of records). These ICU date math operations are highly unoptimized and expensive.
**Action:** Always pre-calculate `DateInterval`s outside loops when checking if dates fall within a specific period (day/week/month/year). For grouping algorithms where dates are temporally clustered, cache the current `DateInterval` to achieve O(1) checking using `interval.contains(date)` instead of recomputing `calendar.startOfDay(for:)` for every item.
