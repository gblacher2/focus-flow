## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-02-09 - Avoid O(n) ICU date math with DateInterval pre-calculation
**Learning:** Performance anti-pattern found in `StatisticsCalculator.swift`: using `Calendar.component` (like `.month`, `.year`) inside a `filter` loop over a large array of records. ICU date math is relatively expensive, causing a CPU bottleneck when repeated for every element in a tight loop.
**Action:** When filtering dates by calendar periods, calculate a single `DateInterval` outside the loop using `calendar.dateInterval(of: .month, for: now)` and use its `.contains(date)` method inside the loop for an O(1) bounds check. Avoid hardcoding durations (like 86400 for days) to prevent DST bugs.
