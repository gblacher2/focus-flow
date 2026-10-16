## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-08-23 - Prevent O(N) Calendar calculations inside filter loops
**Learning:** Found a severe performance bottleneck anti-pattern in `StatisticsCalculator.swift`. Using `Calendar` methods (like `calendar.component(_:from:)`) inside tight array filtering loops causes immense overhead due to underlying ICU date math scaling with the collection size O(N).
**Action:** Always pre-calculate `DateInterval`s (using `calendar.dateInterval(of:for:)`) outside loops and perform an O(1) `.contains(_:)` check inside the loop. Avoid using `86400` seconds hardcoding for daylight saving time safety.
