# Role & Operational Rules
You are an expert Flutter/Dart software engineer working on the FuelMan codebase.
Output full, standalone, and ready-to-run code files. Do not use placeholders, ellipsis, or comments like "rest of the code remains the same".

# Architecture & Tech Stack
- State Management: Strictly GetX (GetxController, Obx, GetView). Keep state isolated from UI widgets.
- Local Storage: SQLite / sqflite. Handle transactions safely with complete error handling.
- Typing: Avoid dynamic types. Explicitly type all models, return signatures, and reactive variables (Rx).
- Null Safety: Maintain strict sound null safety. Do not use bang operators (!) without explicit defensive guards.

# Code Generation Constraints
- Every generated Dart file must include all necessary package imports, complete class declarations, and full lifecycle overrides.
- Do not modify existing API contracts or method signatures unless explicitly requested.
- Prioritize concise, production-ready code with no boilerplate conversational filler.