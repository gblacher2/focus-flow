## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Replace O(N) Calendar Math with O(1) DateInterval
**Learning:** Swift's `Calendar` math functions (like `.component(_:from:)`) are very expensive inside tight loops due to ICU date calculation overhead. When filtering large arrays of dates based on a period, calling these for every element creates an O(N) bottleneck.
**Action:** Instead of dynamically computing components inside `.filter`, pre-calculate a `DateInterval` outside the loop using `calendar.dateInterval(of: .day, for: now)`. The inner loop then uses `interval.contains(date)`, reducing an O(N) ICU operation to O(1) buffer bounds checking.
