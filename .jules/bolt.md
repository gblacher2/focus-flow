## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-28 - Pre-calculate DateInterval for Calendar Math
**Learning:** Swift's `Calendar.component` and related math functions carry heavy ICU overhead. Using them inside tight loops (like filtering records) causes severe O(N) performance bottlenecks. A codebase-specific anti-pattern was found where this was occurring inside a `.filter` block during statistics derivation.
**Action:** Always pre-calculate a single `DateInterval` using `calendar.dateInterval(of:for:)` and use its `contains(_:)` method for O(1) checks during loops, rather than evaluating calendar components per iteration. Never hardcode durations (like 86400 seconds) to avoid DST bugs.
