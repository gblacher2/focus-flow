## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-08-14 - Prevent Calendar overhead in tight loops
**Learning:** Performance bottleneck found: using `Calendar` methods like `.component(_:from:)` and `.startOfDay(for:)` repeatedly within tight loops (like iterating over all records in `StatisticsCalculator`) introduces severe ICU date math overhead, causing performance regressions for large record sets.
**Action:** Avoid `Calendar` methods inside arrays. Pre-calculate `DateInterval`s using `calendar.dateInterval(of:for:)` outside of loops, and use `interval.contains(date)` for O(1) comparison inside the loop. When caching days across consecutive records, cache both the `startOfDay` and the `DateInterval`.
