
## [Unreleased]
### Security & Hardening
- **Fix**: Mitigated memory leaks in `FuelEntryController`, `ChargingEntryController`, and `CarExpenseController` by properly disposing `Worker` stream subscriptions on close.
- **Fix**: Hardened `calculateOverallStats` and `_processIndexedChain` against mathematical edge cases like division-by-zero, `NaN`, and `Infinity` caused by micro-distances or rapid duplicate inputs.
- **Fix**: Enforced stricter validation in `AddEntryScreen` and `AddChargingScreen` restricting negative odometer inputs.
- **Test**: Introduced `test/chaos/chaos_test.dart` to simulate and guard against Fuzzing and chaos-engineering edge-case inputs (overflows, negatives, 0-distance wrapping).

# Changelog
## [Unreleased]
- Интеграция BLE/OBD2 телеметрии.

## [1.1.0] - 2026-09
- Добавлена модель `ChargingEntry` и таблица зарядок в SQLite.
- Реализован сквозной таймлайн для гибридов (PHEV/HEV).
- Расчет комбинированного расхода и л-эквивалента энергии.

## [1.0.0] - 2026-06
- Первоначальный релиз: учет заправок бензиновых авто, GetX архитектура, мультиязычность (ru, en, kk).
