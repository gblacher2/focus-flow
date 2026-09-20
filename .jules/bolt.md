## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2023-10-24 - O(N) Calendar Date Calculations Bottleneck in Tight Loops
**Learning:** Avoid using Swift `Calendar` methods like `.component(_:from:)` or `.isDate(_:inSameDayAs:)` inside tight loops (like filtering large arrays of records). Due to underlying ICU date math overhead, these calls can be a severe performance bottleneck.
**Action:** Always pre-calculate `DateInterval`s (using modern APIs like `calendar.dateInterval(of: .day, for: date)`) before entering loops, and use the O(1) `interval.contains(date)` method for checking inclusions.
