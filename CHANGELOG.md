## [Unreleased]
### Security & Reliability (Chaos Hardening)
- Fixed NaN and Infinity calculation crashes in `FuelEntryController.calculateOverallStats` during fuzzing.
- Fixed a bug where a zero total distance would cause a division by zero error calculating cost per km.
- Sanitized number inputs with `.replaceAll(',', '.')` across entry screens to safely handle numeric input across different locales.


## [Unreleased]
### Security & Hardening
- **Fix**: Mitigated memory leaks in `FuelEntryController`, `ChargingEntryController`, and `CarExpenseController` by properly disposing `Worker` stream subscriptions on close.
- **Fix**: Prevented double-tap race conditions in all save screens, stopping duplicate database entries.
- **Fix**: Blocked time manipulation attacks by rejecting future dates during entry saves.
- **Fix**: Ensured safe cross-locale number parsing by replacing commas with dots before `double.tryParse` on all number fields.
- **Fix**: Hardened `calculateOverallStats` and `_processIndexedChain` against mathematical edge cases like division-by-zero, `NaN`, and `Infinity` caused by micro-distances or rapid duplicate inputs.
- **Fix**: Enforced stricter validation in `AddEntryScreen` and `AddChargingScreen` restricting negative odometer inputs.
- **Fix**: Prevented UI state race conditions by enforcing early return blocking double-taps on save buttons across all data entry screens.
- **Fix**: Prevented saving records with a date in the future to maintain data integrity.
- **Fix**: Improved error logging by replacing silent swallowing and `debugPrint` with proper stack trace logging via `dart:developer`.
- **Fix**: Prevented state race conditions in `FuelEntryController`, `ChargingEntryController`, and `CarExpenseController` where switching the active vehicle during an async save operation could cause the UI to load data for the wrong vehicle.
- **Fix**: Added strict validation in `FuelEntryController.validateOdometer` to explicitly reject negative odometer values.
- **Feature**: Added automatic 3-way synchronization and live calculation among fuel volume, unit price, and total cost in `FuelEntryController` and `AddEntryScreen` to eliminate calculation mismatches in SQLite database.
- **Test**: Expanded `test/chaos/chaos_test.dart` and `test/controllers/fuel_entry_controller_test.dart` with comprehensive chaos fuzzing and 3-way synchronization test suites.

# Changelog
## [Unreleased]
- Интеграция BLE/OBD2 телеметрии.

## [1.1.0] - 2026-09
- Добавлена модель `ChargingEntry` и таблица зарядок в SQLite.
- Реализован сквозной таймлайн для гибридов (PHEV/HEV).
- Расчет комбинированного расхода и л-эквивалента энергии.

## [1.0.0] - 2026-06
- Первоначальный релиз: учет заправок бензиновых авто, GetX архитектура, мультиязычность (ru, en, kk).

## [Unreleased]
### Added
- Added unit tests for `ChargingEntry` data model to verify calculation logic and serialization.
