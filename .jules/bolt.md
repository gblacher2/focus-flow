## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar methods in tight loops
**Learning:** Calling `Calendar` methods like `.component(_:from:)` or `.isDate(_:inSameDayAs:)` inside tight loops causes severe performance bottlenecks due to ICU date math overhead. This is an anti-pattern when processing many records.
**Action:** Pre-calculate `DateInterval`s using `calendar.dateInterval(of:for:)` outside the loop, and use `DateInterval.contains(_:)` for O(1) checking inside the loop. Avoid hardcoding durations (e.g. 86400 for a day) to prevent DST bugs.
