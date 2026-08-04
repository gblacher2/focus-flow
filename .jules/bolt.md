## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-08-04 - Pre-calculate DateInterval for Calendar math in loops
**Learning:** Swift `Calendar` methods (like `.component(_:from:)`) are very slow due to underlying ICU date math overhead, making them an anti-pattern when used inside tight loops (like filtering an array of records).
**Action:** Pre-calculate a `DateInterval` using `calendar.dateInterval(of:for:)` outside of the loop, then use `interval.contains(date)` inside the loop for O(1) performance instead of recalculating calendar boundaries on every iteration.
