## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-01-20 - Calendar ICU Date Math Overhead inside tight loops
**Learning:** Using `Calendar.component(_:from:)` or `Calendar.isDate(_:inSameDayAs:)` inside tight array filtering loops (like filtering statistics by date) causes massive performance overhead due to ICU date math.
**Action:** Always pre-calculate the required time window using `calendar.dateInterval(of: <component>, for: date)` outside the loop, then use the resulting `DateInterval.contains(_:)` for an O(1) double comparison inside the loop. Never hardcode durations (e.g. 86400 seconds) to avoid Daylight Saving Time bugs.
