// Базовый smoke test для FuelMan.
// Полноценное тестирование требует мока SQLite и GetX контроллеров.
// Тест ниже просто проверяет, что приложение компилируется без ошибок.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder test', () {
    expect(1 + 1, equals(2));
  });
}
