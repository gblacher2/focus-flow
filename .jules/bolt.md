## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.

**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-10-25 - Pre-calculate DateIntervals for calendar comparisons
**Learning:** Avoid using `Calendar.component(_, from:)` or `Calendar.isDate` inside tight loops (like filtering collections) in Swift. The underlying ICU date math adds heavy overhead.
**Action:** Always pre-calculate a `DateInterval` for the period using `calendar.dateInterval(of:for:)` outside the loop, and use `interval.contains(date)` for fast O(1) checks. Never hardcode durations (e.g. 86400 seconds) to avoid DST bugs.
