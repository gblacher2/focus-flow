## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2025-01-20 - Avoid Calendar math in tight loops
**Learning:** `Calendar` component methods (like `component(_:from:)`) are expensive because of the underlying ICU date math operations. Running them inside a loop (like `filter` or `map`) over a large collection creates a massive performance bottleneck.
**Action:** Instead of doing date component checks on each element, pre-calculate a `DateInterval` outside of the loop and use `interval.contains(date)` which provides an O(1) mathematical check.
