## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-08-30 - Pre-calculate DateInterval for Date math
**Learning:** Swift's `Calendar` methods (e.g., `.component(_:from:)` or `isDate(_:inSameDayAs:)`) cause severe performance bottlenecks when used inside tight loops (like O(N) array filters) due to ICU date math overhead.
**Action:** Pre-calculate `DateInterval` objects using `calendar.dateInterval(of:for:)` outside the loop, and use the O(1) `interval.contains(date)` method inside the loop.
