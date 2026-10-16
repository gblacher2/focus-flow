## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Optimize Calendar usage inside filtering loops
**Learning:** Calling Calendar methods (like `.component(_:from:)` or `.isDate(_, inSameDayAs:)`) inside tight loops over large datasets creates a severe performance bottleneck due to ICU date math overhead.
**Action:** Always pre-calculate the boundaries of the interval using `calendar.dateInterval(of: .day, for: date)` outside the loop, and use Swift's `DateInterval.contains()` inside the loop for O(1) comparison. Do not hardcode seconds for durations to avoid Daylight Saving Time (DST) bugs.
