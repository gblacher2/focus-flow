## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-08-25 - Avoid Calendar math in tight loops
**Learning:** Performance Anti-Pattern (Swift) - Using `Calendar` methods like `.component(_:from:)` or `.isDate(_:inSameDayAs:)` inside tight loops causes severe performance bottlenecks due to ICU date math overhead (in this case, evaluating whether session records match a filter period).
**Action:** When calculating if a sequence of dates falls within a specific period (day/week/month/year), pre-calculate the boundaries using `calendar.dateInterval(of: <component>, for: date)` before the loop. Use the resulting `DateInterval.contains(date)` for O(1) checking.
