**Summary**: This PR addresses chaos engineering edge cases and localization bugs found during fuzzing and aggressive boundary testing of the `FuelMan` application.

**Vulnerabilities & Edge Cases Discovered**:
| Vulnerability | Attack Vector | Risk |
| --- | --- | --- |
| Fuzzing crashes (NaN / Infinity) | Extreme values like 0 for distance, or NaN values injected into calculation flow. | Unhandled exceptions in `calculateOverallStats` crash the statistics view. |
| Division by zero | Start and end odometer are the exact same for all entries. | Yields `Infinity` for cost per km, distorting graphs. |
| Locale numeric parsing | Passing string numbers like `12,5` (Russian locale) to `double.tryParse`. | Fails silently and yields 0 or throws `null`, losing user input for fuel consumption. |

**Fixes & Hardening**:
- Updated `FuelEntryController.calculateOverallStats` to check `isNaN` and `isInfinite` for intermediate math components and filter bad data.
- Added `isFinite` and zero checks before doing division calculation on metrics.
- Hardened all data-entry forms by appending `.replaceAll(',', '.')` before calling `double.tryParse` across `add_charging_screen.dart` and `add_vehicle_screen.dart` to handle locale decimal commas cleanly.
- `_date.isAfter(DateTime.now())` guards exist across data entry views.

**Tests Added**:
- Fuzzing & Chaos tests (`test/chaos/fuzzing_test.dart`) for testing `calculateOverallStats` with NaN, Infinity, and division-by-zero states.
- Locale number parsing tests (`test/chaos/locale_test.dart`) for numeric input handling.

**Documentation Updates**:
- `CHANGELOG.md` updated with hardening fixes.
