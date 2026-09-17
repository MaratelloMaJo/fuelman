
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
- **Fix**: Cascading cleanup added to `VehicleController` to explicitly flush memory cache states in `FuelEntryController`, `ChargingEntryController`, and `CarExpenseController` when a vehicle is deleted.
- **Test**: Expanded `test/chaos/chaos_test.dart` to simulate and guard against Fuzzing and chaos-engineering edge-case inputs (overflows, negatives, 0-distance wrapping, and future date bypass structures), including PHEV logic collisions (zero consumption, negative volume/recuperation) and out-of-order date entries.

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
