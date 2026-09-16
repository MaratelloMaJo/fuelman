# Changelog

## [Unreleased]
- Интеграция BLE/OBD2 телеметрии.


## [1.1.1] - Security & Resilience Patch
- Fixed Race Conditions causing duplicate database entries on rapid save button taps.
- Added strict time-manipulation checks (future dates are no longer allowed).
- Hardened database import to prevent app crashes from corrupted or malicious DB files.
- Resolved memory leaks in GetX state management by explicitly disposing of state listeners (`ever()` workers) in `onClose()`.
- Improved number parsing to gracefully handle localized separators, whitespace, and emoji garbage without crashing.

## [1.1.0] - 2026-09
- Добавлена модель `ChargingEntry` и таблица зарядок в SQLite.
- Реализован сквозной таймлайн для гибридов (PHEV/HEV).
- Расчет комбинированного расхода и л-эквивалента энергии.

## [1.0.0] - 2026-06
- Первоначальный релиз: учет заправок бензиновых авто, GetX архитектура, мультиязычность (ru, en, kk).
