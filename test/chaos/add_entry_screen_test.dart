import 'package:flutter_test/flutter_test.dart';

void main() {
  test('double.tryParse replacement test', () {
    String input = '123,45';
    double val = double.tryParse(input.replaceAll(',', '.')) ?? 0.0;
    expect(val, 123.45);

    input = '';
    val = double.tryParse(input.replaceAll(',', '.')) ?? 0.0;
    expect(val, 0.0);

    input = 'abc';
    val = double.tryParse(input.replaceAll(',', '.')) ?? 0.0;
    expect(val, 0.0);
  });
}
