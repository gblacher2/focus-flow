## 2024-05-24 - Precomputing Calendar Intervals in Loops
**Learning:** Foundation's `Calendar.component` and `Calendar.isDate` are computationally expensive when called inside tight loops (like filtering records for a UI during every render). Using them in O(N) filters causes unnecessary CPU overhead.
**Action:** Precompute the `Calendar.dateInterval` for the target period outside the loop. Use primitive `Date` comparisons (`date >= interval.start && date < interval.end`) inside the loop. This reduces calendar operations from O(N) to O(1).
