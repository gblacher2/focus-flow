## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-08-20 - Pre-calculate DateIntervals to avoid Calendar ICU overhead in loops
**Learning:** Performance Anti-Pattern (Swift) found: Using `Calendar` methods (like `.component(_:from:)` or `.isDate(_:inSameDayAs:)`) inside tight loops (like `Array.filter`) causes severe performance bottlenecks due to ICU date math overhead.
**Action:** Pre-calculate `DateInterval`s using modern APIs like `calendar.dateInterval(of: .day, for: date)` before entering the loop. This converts complex date math into a simple `O(1)` check via `interval.contains(date)`. Never hardcode durations (e.g., 86400 seconds) for intervals as it introduces DST bugs.
