## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-09-06 - Optimize session filtering performance by caching DateIntervals
**Learning:** In Swift, using `Calendar` methods (like `.component(_:from:)`) inside tight loops (like array filters) can cause severe performance bottlenecks due to the overhead of ICU date math. This is a critical pattern to recognize when filtering large sets of time-series data.
**Action:** When filtering dates by a specific period (day, week, month, year), always pre-calculate a `DateInterval` using `calendar.dateInterval(of:for:)` outside the loop, and use the O(1) `interval.contains(date)` check inside the loop.
