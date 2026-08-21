## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-09 - Avoid Calendar math inside tight loops
**Learning:** Performance Anti-Pattern (Swift) found: Using `Calendar` methods (like `calendar.component(_:from:)` or `calendar.isDate(_:inSameDayAs:)`) inside tight `.filter` loops causes severe performance bottlenecks due to ICU date math overhead.
**Action:** When evaluating if dates fall within a certain period, always pre-calculate `DateInterval`s (e.g. `calendar.dateInterval(of: .day, for: now)`) outside the loop for an O(1) `interval.contains(date)` check inside the loop. Never hardcode durations (e.g., 86400 seconds) as it introduces Daylight Saving Time (DST) bugs.
