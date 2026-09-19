## Summary
Implemented security and chaos hardening fixes to the FuelMan project to address edge cases, memory leaks, invalid state cache issues, date manipulation, and robustness during mathematical overflows.

## Vulnerabilities & Edge Cases Discovered
| Vulnerability | Description | Risk Level |
| ------------- | ----------- | ---------- |
| Memory Leak in `FuelEntryController` | `_workers` list holding `ever()` reactive listeners were not disposed of, causing continuous memory bloat when switching vehicle scopes. | Medium |
| State Cache Orphans in `VehicleController` | Deleting a vehicle didn't instruct dependent GetX controllers (`FuelEntryController`, etc) to clear their cached states, leading to corrupted data views post-deletion. | High |
| Missing Validation for Future Dates | Users could inject future dates in `add_entry_screen.dart`, `add_expense_screen.dart`, and `add_charging_screen.dart`, potentially corrupting time-based chronological calculations. | Medium |
| Floating Point Math Overflow / Div by Zero in `FuelEntryController` | Micro-deltas or missing data in math pipelines could throw div by zero or return `Infinity`/`NaN`. | Low |

## Fixes & Hardening
- Added an `onClose()` lifecycle hook to `FuelEntryController` to iterate through and properly dispose of all `_workers`.
- Bound dependent controller cleanups in `VehicleController` by explicitly calling `_onVehicleChanged()` upon successful deletion.
- Enforced strict temporal guard clauses rejecting future dates in all data creation screens.
- Validated SQLite operations, `whereArgs` parametrization is already universally used correctly preventing SQL-i.

## Tests Added
- `test/chaos/chaos_test.dart` containing 5 core test cases verifying:
  - Overflows and Negative Values
  - Zero Division and Micro distances
  - Odometer Reset / Wrap Around
  - Division by zero in stats calculation with zero distance
  - Future Date Validation

## Documentation Updates
- Updated `CHANGELOG.md` to reflect the security and stability improvements introduced by the hardening suite.
