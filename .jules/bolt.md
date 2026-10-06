## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-08-23 - Pre-calculate date intervals for O(1) checking
**Learning:** Avoid using `Calendar` methods (like `.component(_:from:)`) inside tight loops like `filter` or `map`. Date math in Foundation is backed by ICU and adds significant overhead when invoked for thousands of records. `DateInterval` provides highly efficient O(1) checks.
**Action:** Always pre-calculate the `DateInterval` for the period in question using `calendar.dateInterval(of:for:)` before looping, and simply check if `interval.contains(date)` inside the loop.
