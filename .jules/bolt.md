## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Optimize Calendar usage in filtering
**Learning:** Found a severe performance bottleneck specific to this codebase: invoking `Calendar.component` and `Calendar.isDate(_:inSameDayAs:)` iteratively in the `.filter` closures of `StatisticsCalculator.records`. Calling ICU-backed date math for every element creates significant overhead, especially since records can grow large.
**Action:** When filtering dates by period (day, week, month, year), calculate a `DateInterval` up front using `calendar.dateInterval(of:for:)` and use `interval.contains(date)`. This reduces the complexity to O(1) inside the loop, eliminating repeated date calculations.
