## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-08-11 - Avoid Calendar Methods in Tight Loops
**Learning:** Found a severe performance anti-pattern in `StatisticsCalculator.swift`: using Swift's `Calendar` API (e.g., `calendar.isDate(_:inSameDayAs:)` or `calendar.component(_:from:)`) inside `.filter` loops. Calendar operations are notoriously slow due to ICU date math overhead, causing bottlenecks as data size grows.
**Action:** Always pre-calculate bounds using `calendar.dateInterval(of:for:)` outside of loops for time-based filtering. Then use the resulting `DateInterval` to perform O(1) `.contains(date)` checks instead. Never hardcode durations (like 86400 seconds) for these intervals to avoid Daylight Saving Time bugs.
