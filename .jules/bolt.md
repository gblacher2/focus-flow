## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar components in tight loops
**Learning:** Found a severe performance anti-pattern in `StatisticsCalculator.swift`. Using `Calendar` methods (like `.component(_:from:)`) inside tight loops (like filtering a large array of records) causes major bottlenecks due to heavy ICU date math overhead.
**Action:** Always pre-calculate `DateInterval`s using `calendar.dateInterval(of:for:)` before entering loops, and use `interval.contains(date)` for O(1) checking. Never hardcode durations (e.g., 86400 seconds) to avoid DST bugs.
