## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Cache Calendar intervals to prevent loop ICU overhead
**Learning:** Found a major performance anti-pattern in Swift where using `Calendar` methods (like `.component(_:from:)` and `.isDate(_, inSameDayAs:)`) inside tight loops (like array filtering over thousands of records) causes severe CPU spikes due to repetitive ICU date math overhead.
**Action:** Avoid executing Calendar logic per item. Pre-calculate target date windows as `DateInterval`s (using `calendar.dateInterval(of:for:)`) outside loops and use the O(1) `interval.contains(date)` for membership checks inside the loop. Never hardcode durations (e.g. 86400s) to bypass Calendar; rely on `DateInterval` to safely handle daylight saving transitions.
