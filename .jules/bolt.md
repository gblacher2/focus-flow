## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-11-20 - Avoid Calendar operations in tight loops
**Learning:** Calling `Calendar` methods (like `.component(_:from:)` or `.isDate(_:inSameDayAs:)`) inside tight filtering loops (like array `.filter`) introduces significant performance bottlenecks due to the overhead of ICU date math underneath.
**Action:** Always pre-calculate standard periods (day, week, month, year) using `calendar.dateInterval(of:for:)` before the loop, and use Swift's `DateInterval.contains(_:)` to perform fast, O(1) checks on each element.
