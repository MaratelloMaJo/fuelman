**Summary**: Chaos engineering and security hardening for the fuelman app. Conducted aggressive fuzzing and state testing on edge cases, vulnerabilities, and concurrency flaws.

**Vulnerabilities & Edge Cases Discovered**:
| Vulnerability | Attack Vector / Risk |
| --- | --- |
| Double Parsing Exception | `FormatException` when parsing number inputs with `double.parse()`. Can lead to app crashes. |
| Orphaned State | Deleting a vehicle deletes it from SQLite via CASCADE, but leaves caches in `FuelEntryController`, `ChargingEntryController`, and `CarExpenseController` if not correctly cleared. |

**Fixes & Hardening**:
- Replaced all instances of `double.parse()` with `double.tryParse()` in `add_entry_screen.dart`, `add_expense_screen.dart`, and `add_charging_screen.dart`. When `null`, we fall back to a safe value (`-1.0` or `0.0` depending on context) which is appropriately caught by existing input validators instead of crashing.
- `VehicleController` already correctly calls `_clearRelatedControllersState()` inside `deleteVehicle` to clear `FuelEntryController`, `ChargingEntryController`, and `CarExpenseController` state caches.
- Added a comment in `lib/database/fuel_database.dart` confirming `ON DELETE CASCADE` handles orphaned records correctly, supported by `PRAGMA foreign_keys = ON` in the init.

**Tests Added**:
- `test/chaos/hard_chaos_test.dart`: Added test for zero fuel consumption (100% electric PHEV), extremely large delta distances, and negative consumption due to recuperation.
- `test/chaos/vehicle_controller_delete_test.dart`: Added a test to ensure `deleteVehicle()` correctly clears related controller states and prevents orphaned state cache.
- `test/chaos/add_entry_screen_test.dart`: Tested `double.tryParse` behavior.
- `test/chaos/time_manipulation_test.dart`: Fuzzed time data mapping for edge cases where data was added out of chronological order.

**Documentation Updates**:
- `CHANGELOG.md` updated with "Security & Chaos Hardening Suite".
