## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-05-18 - Avoid Calendar methods in tight loops
**Learning:** Using `Calendar.component` inside an O(N) loop (e.g., filtering a list of records) is a severe performance bottleneck due to the underlying ICU library date math overhead.
**Action:** Always pre-calculate `DateInterval`s using `calendar.dateInterval(of:for:)` before the loop, and use `interval.contains(date)` inside the loop for an O(1) check. This takes performance from O(N * Calendar overhead) down to true O(N).
