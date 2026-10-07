## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.
## 2024-07-29 - O(1) Date Interval checking
**Learning:** Found a Swift performance anti-pattern where `Calendar` methods like `.component(_:from:)` were used inside tight loops (like `.filter`), causing severe performance bottlenecks due to ICU date math overhead.
**Action:** When calculating statistics over periods, always pre-calculate `DateInterval`s using `calendar.dateInterval(of: .day, for: date)` instead, and leverage O(1) interval bounds checking within the loop. Avoid hardcoding durations.
