## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-08-01 - Avoid Calendar component math in tight loops
**Learning:** Performance Anti-Pattern (Swift) found: Using `Calendar` methods (like `.component(_:from:)`) inside tight loops (like `Array.filter`) causes severe performance bottlenecks due to expensive ICU date math overhead (`O(N)` scaling with high constants).
**Action:** Pre-calculate `DateInterval`s using modern APIs like `calendar.dateInterval(of:for:)` before the loop. This enables `interval.contains(date)` for `O(1)` checking per element, eliminating the overhead inside the loop. When optimizing, avoid hardcoding durations (like 86400s) to prevent Daylight Saving Time (DST) bugs.
