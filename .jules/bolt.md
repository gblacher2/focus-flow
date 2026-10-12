## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-26 - Optimized Calendar calculations inside tight loops
**Learning:** Calling Swift `Calendar` methods (e.g. `calendar.component` or `calendar.isDate`) inside a large array `.filter()` loop is a severe performance bottleneck due to ICU date math overhead.
**Action:** Always pre-calculate the bounding `DateInterval` outside the loop (using modern APIs like `calendar.dateInterval(of: .day, for: date)` to safely handle DST) and use its O(1) `.contains(_:)` method inside the closure for checking dates.
