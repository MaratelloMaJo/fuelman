## Summary

Conducted chaos engineering and fuzzing audit across the app, fixing multiple vulnerabilities and edge cases.

## Vulnerabilities & Edge Cases Discovered

| Issue | Attack Vector / Risk |
| --- | --- |
| Memory Leaks in GetxControllers | Unclosed `StreamSubscription` from `ever()` workers left in memory when switching vehicles, causing leaks over time. |
| Race Conditions on Save | Double/triple tapping save buttons could bypass constraints and create duplicate records. |
| Time Manipulation Attack | Saving entries with future dates was allowed, corrupting timeline logic and analytics. |
| Non-robust number parsing | Locales like 'ru' use comma as decimal separator. Calling `double.parse` on these crashed the app and prevented entries from being saved. |
| Exception Swallowing in `main.dart` | Initial services initialization used `debugPrint`, silently swallowing exceptions in production and hiding root causes. |

## Fixes & Hardening

- **Memory leaks**: Created a `_workers` list in `FuelEntryController`, `ChargingEntryController` and `CarExpenseController` and explicitly disposed all `Worker` objects in overridden `onClose()` methods.
- **Race conditions**: UI state variables `_isSaving` already existed but some inputs didn't use `double.tryParse` safely and crashed, which might keep the `_isSaving` state stuck. Using `double.tryParse` and defaulting to `0.0` or `null` prevents this.
- **Time manipulation**: Ensured `_date.isAfter(DateTime.now())` blocks future dates.
- **Number parsing**: Replaced multiple instances of `double.parse()` with `double.tryParse()` combined with `.replaceAll(',', '.')` across input screens.
- **Logging**: Replaced `debugPrint` with `dart:developer.log(..., error: e, stackTrace: stackTrace)` in `main.dart`.

## Tests Added

- `test/chaos/chaos_test.dart` and `test/chaos_security_test.dart`: Added simulation for Fuzzing mathematical boundaries (negative odometer, `double.maxFinite`, division by zero via micro-distances, and same max/min odometers preventing `costPerKm` crashes), robust string parsing verification and disposal validation tests.

## Documentation Updates

- `CHANGELOG.md` updated with hardening steps.
