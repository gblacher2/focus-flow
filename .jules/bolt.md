## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-09-04 - Optimize Calendar math in loops using DateInterval
**Learning:** Swift's `Calendar` component methods (e.g., `.component(_:from:)`) invoke heavy ICU date math. Calling these inside tight loops like `.filter` over arrays creates severe O(N) performance bottlenecks. Pre-calculating `DateInterval` provides `O(1)` `contains(_:)` checks.
**Action:** Never use `Calendar` math directly inside collection operations. Always pre-calculate bounds as a `DateInterval` (using modern APIs like `calendar.dateInterval(of: .day, for: date)` to avoid DST bugs) before the loop.
