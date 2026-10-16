## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-08-01 - Avoid Calendar date math in tight loops
**Learning:** Performance Anti-Pattern (Swift) found: doing expensive `Calendar` component extractions (like `.component(_:from:)`) for every single element in a filter loop causes an O(N) bottleneck due to heavy ICU date math overhead.
**Action:** When filtering dates based on a range, pre-calculate `DateInterval`s instead using `calendar.dateInterval(of:for:)` to allow O(1) checking using `interval.contains`. Never hardcode durations (like 86400 seconds) to avoid DST bugs.
