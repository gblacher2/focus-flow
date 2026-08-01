## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-26 - Pre-calculate DateInterval to avoid Calendar component overhead
**Learning:** Calling `Calendar.component(_:from:)` or similar methods inside a `.filter` block over an array is a severe performance anti-pattern. ICU date math causes significant overhead (often O(N) penalty) which can slow down main-thread operations, especially during high-frequency events like timer ticks.
**Action:** Pre-calculate the `DateInterval` using the modern `calendar.dateInterval(of:for:)` API *before* the loop. Inside the loop, check `interval.contains(date)`, which takes advantage of O(1) comparison logic.
