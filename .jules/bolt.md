## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Avoid Calendar methods in tight loops
**Learning:** Performance Anti-Pattern (Swift): Avoid using `Calendar` methods (like `.component(_:from:)` or `.isDate(_:inSameDayAs:)`) inside tight loops, such as `Array.filter` applied to large datasets. They cause severe performance bottlenecks due to ICU date math overhead on every iteration.
**Action:** Pre-calculate a `DateInterval` based on the given components outside of the loop using `calendar.dateInterval(of:for:)`, then use the O(1) `interval.contains(date)` method inside the loop. Never hardcode durations (e.g., 86400 seconds for a day) for this, as it introduces bugs for daylight saving time boundaries.
