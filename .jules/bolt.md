## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-08 - Prevent ICU Date Math Overhead in Tight Loops
**Learning:** Performance Anti-Pattern (Swift) found: using `Calendar` methods (like `.component(_:from:)` or `.isDate(_, inSameDayAs:)`) inside tight loops (like filtering an array of objects) causes severe performance bottlenecks due to the overhead of ICU date math underneath.
**Action:** Always pre-calculate `DateInterval`s (using modern APIs like `calendar.dateInterval(of: .day, for: date)`) outside the loop, and use `interval.contains(date)` for O(1) checking instead of recalculating calendar boundaries on every iteration.
