import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Locale Number Parsing', () {
    test('Replace all comma with dot handles both', () {
      const ru = '12,5';
      const en = '12.5';

      final parsedRu = double.tryParse(ru.replaceAll(',', '.'));
      final parsedEn = double.tryParse(en.replaceAll(',', '.'));

      expect(parsedRu, 12.5);
      expect(parsedEn, 12.5);
    });
  });
}
