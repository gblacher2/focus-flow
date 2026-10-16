## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-05-18 - Avoid O(N) Calendar Component Lookups
**Learning:** In Swift, `Calendar.component(_:from:)` calls involve heavy ICU date math overhead, causing severe bottlenecks if executed inside large loops or O(N) filters like `AppModel`'s statistics recalculation.
**Action:** Always pre-compute a `DateInterval` using `calendar.dateInterval(of:for:)` before the loop, and use `interval.contains(date)` for an O(1) inside loop operation, avoiding hardcoded durations to prevent Daylight Saving Time (DST) bugs.
