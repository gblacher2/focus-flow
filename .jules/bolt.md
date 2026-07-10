## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2026-07-10 - Reuse ISO8601DateFormatter to prevent O(N) allocations in loops
**Learning:** Found an `ISO8601DateFormatter()` instantiation inside a `.map` loop traversing `SessionRecord` arrays in `CSVExporter.swift`. Instantiating date formatters in Foundation is known to be an expensive operation, and creating multiple instances inside a loop scales poorly (O(N) cost) and negatively affects memory and performance.
**Action:** Always instantiate Foundation formatters (like `DateFormatter` or `ISO8601DateFormatter`) once outside of tight loops or map/filter/reduce operations, and reuse the single instance for all formatting calls within the loop.
