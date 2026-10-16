## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-01-28 - Optimize Swift Calendar Calculations in Loops
**Learning:** Performance Anti-Pattern (Swift) found: using `Calendar` methods (like `.component(_:from:)` or `.isDate(_:inSameDayAs:)`) inside tight loops (like `filter`) causes severe performance bottlenecks due to ICU date math overhead.
**Action:** Always pre-calculate `DateInterval`s (e.g. using `calendar.dateInterval(of: .day, for: now)`) before the loop, and use `interval.contains(date)` for an O(1) check. Never hardcode durations (like 86400 seconds) to avoid Daylight Saving Time (DST) bugs for 23/25 hour days.
