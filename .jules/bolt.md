## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-09-10 - Optimize Date Math inside Loops
**Learning:** Calendar component lookups inside tight loops (like filter) are a significant performance bottleneck in Swift due to ICU date math overhead.
**Action:** Use pre-calculated DateIntervals before entering the loop to enable O(1) containment checks instead of invoking Calendar repeatedly inside the loop.
