## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-10-24 - Pre-calculate DateInterval for Calendar checks in loops
**Learning:** Swift `Calendar` operations (like `.component(_:from:)` and `.isDate(_:inSameDayAs:)`) use expensive ICU date math which can create significant performance overhead when executed inside tight loops (like filtering large arrays of records).
**Action:** Pre-calculate `DateInterval` outside of loops for time periods and use the O(1) `DateInterval.contains(_:)` method inside the loop. Always use modern `calendar.dateInterval(of: ..., for: ...)` APIs rather than hardcoded durations (e.g., 86400 seconds) to avoid Daylight Saving Time (DST) edge cases.
