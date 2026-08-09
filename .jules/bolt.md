## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2026-08-09 - Avoid ICU date math in tight loops
**Learning:** Using `Calendar` methods like `.component(_:from:)` or `.isDate(_:inSameDayAs:)` inside array filtering loops causes severe performance bottlenecks due to the overhead of ICU date math evaluated on every element.
**Action:** Always pre-calculate a `DateInterval` outside the loop using modern APIs like `calendar.dateInterval(of: .day, for: date)` and use the O(1) `.contains()` method for range checking during iteration.
