## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-11-20 - Avoid Calendar functions in tight loops
**Learning:** Found a performance anti-pattern where ICU date math (`Calendar.component(_:from:)`, etc.) was being called inside a `filter` loop for every `SessionRecord`. This introduces significant overhead on array transformations.
**Action:** Always pre-calculate bounds using `calendar.dateInterval(of:for:)` before looping, and use the O(1) `DateInterval.contains(_:)` method inside the loop. Avoid manual date boundaries that can fail on DST.
