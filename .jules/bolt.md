## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-08 - Fast Calendar Math
**Learning:** Swift `Calendar` methods like `.component(_:from:)` are heavily tied to ICU and are an extreme bottleneck when run in tight loops, significantly tanking performance for calculations running continuously (like stats filtering on every render or second update).
**Action:** Avoid extracting calendar components inside filtering loops. Instead, pre-calculate `DateInterval`s representing the range to filter before the loop (via `calendar.dateInterval(of:for:)`), then use `.contains(_:)` within the loop, which runs in O(1) time and bypasses ICU overhead. Always use the provided API `dateInterval` rather than hardcoding durations like 86400 to account for DST changes.
