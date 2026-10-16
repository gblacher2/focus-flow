## 2024-07-08 - Prevent per-second statistics recalculation
**Learning:** SwiftUI anti-pattern found: doing O(N log N) array filtering and sorting inside computed properties of a view (`StatisticsView.swift`) that observes an `AppModel` triggering updates every second (on timer tick). Swift `Array` equality checking is `O(1)` when unmodified due to buffer identity, making it extremely efficient to use as a dependency in `.onChange`.
**Action:** Cache expensive derived data calculations using `@State` variables and `.onChange(of: filterParams)` rather than computing them directly inside properties that will be evaluated on every single View render.

## 2024-07-12 - DateFormatter Instance Caching
**Learning:** `DateFormatter` initialization in Foundation/Swift is notoriously slow. Instantiating it directly inside a heavily-used formatting function like `AppFormatters.dayHeader` causes excessive allocations and frame drops, particularly when evaluated repeatedly (e.g., when building view lists or grouping statistics).
**Action:** Always extract and statically cache `DateFormatter` (or `ISO8601DateFormatter`, `NumberFormatter`) instances. This applies directly to UI performance for list rendering in SwiftUI.
