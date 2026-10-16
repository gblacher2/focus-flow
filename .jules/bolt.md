## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Optimize Calendar calculations using DateInterval
**Learning:** Performance Anti-Pattern (Swift): Using `Calendar` methods (like `.component(_:from:)` or `.isDate(_:inSameDayAs:)`) inside tight array loops (e.g., `.filter`) causes severe performance bottlenecks due to ICU date math overhead.
**Action:** When filtering dates by period, pre-calculate the `DateInterval` for the period using `calendar.dateInterval(of: <component>, for: date)` *outside* the loop, then use `interval.contains(date)` inside the loop for O(1) checking. Never hardcode durations (like 86400 seconds) for things like days, as it introduces Daylight Saving Time (DST) bugs.
