## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-05-24 - Avoid Calendar components in tight loops
**Learning:** Checking `Calendar` components (e.g., `calendar.component(_:from:)`) inside a tight filter loop on large arrays introduces significant performance overhead due to ICU date math.
**Action:** Always pre-calculate bounds (e.g., as `DateInterval` or `Range<Date>`) using `calendar.dateInterval(of:...)` before iterating, allowing for O(1) checking using `interval.contains(date)` within the loop.
