## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-01-20 - Prevent O(N) ICU date math on large datasets
**Learning:** Swift's `Calendar` methods (like `.component(_:from:)` or `.startOfDay(for:)`) cause severe performance bottlenecks inside tight loops due to underlying ICU date math overhead, which is surprisingly slow.
**Action:** Optimize calendar calculations by pre-calculating `DateInterval`s using `calendar.dateInterval(of:for:)` outside loops, enabling O(1) `interval.contains(date)` checking. Do not hardcode durations for this to avoid DST bugs.
