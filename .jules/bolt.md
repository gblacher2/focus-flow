## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-10-24 - O(1) DateInterval Caching for Performance
**Learning:** Performance Anti-Pattern (Swift) found: calling `Calendar` methods (like `component(_:from:)`) inside tight loops causes significant overhead due to costly ICU date math. For instance, filtering an array based on date matching can be very slow.
**Action:** When filtering or checking dates in loops, pre-calculate `DateInterval`s using `calendar.dateInterval(of:for:)` outside the loop, and use `interval.contains(date)` for O(1) evaluation.
