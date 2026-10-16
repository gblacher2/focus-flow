## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-09-12 - Pre-calculate DateInterval for fast Calendar logic
**Learning:** Swift Calendar math (like `.component` and `.startOfDay`) incurs significant ICU overhead and acts as a major performance bottleneck inside tight loops (like filtering or grouping large arrays). Using hardcoded durations to bypass it introduces DST bugs.
**Action:** Avoid `Calendar` methods in loops. Instead, pre-calculate `DateInterval`s using `calendar.dateInterval(of:for:)` outside the loop, and use O(1) `interval.contains(date)` inside the loop for both speed and safety.
