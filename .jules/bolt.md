## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-01-20 - Prevent O(N) Calendar method evaluation in tight loops
**Learning:** Found an anti-pattern in `StatisticsCalculator.records` where `Calendar` methods (like `.component(_:from:)` and `.isDate(_:inSameDayAs:)`) were used inside an array `.filter` over session records. This can cause severe performance bottlenecks on large data sets due to the high overhead of ICU date math underneath Foundation's `Calendar`.
**Action:** Replace direct Calendar method calls in tight loops by pre-calculating a `DateInterval` and using it for an O(1) bound check (`date >= interval.start && date < interval.end`).
