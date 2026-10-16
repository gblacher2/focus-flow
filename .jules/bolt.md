## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-05-18 - Hoist Calendar Operations Out of Loops
**Learning:** Checking calendar intervals (like `.isDate` or `.component`) inside an `$O(n)$` `.filter` loop is a significant performance bottleneck in Swift because `Calendar` operations are surprisingly expensive.
**Action:** Always pre-calculate the `DateInterval` for the required period outside the loop, and use `interval.contains(date)` inside the loop to drastically improve date filtering performance.
