
import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/settings_controller.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsController Test', () {
    late SettingsController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'language': 'ru',
        'currency': 'RUB',
        'volume_unit': 'L',
        'distance_unit': 'km',
      });
      Get.testMode = true; // Set get test mode
      controller = SettingsController();
      Get.put(controller);

      // Wait for onInit and _loadSettings
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      Get.delete<SettingsController>();
    });

    test('Initial values are loaded correctly', () {
      expect(controller.language.value, 'ru');
      expect(controller.currency.value, 'RUB');
      expect(controller.volumeUnit.value, 'L');
      expect(controller.distanceUnit.value, 'km');
    });

    test('Updating language updates SharedPreferences', () async {
      await controller.setLanguage('en');
      expect(controller.language.value, 'en');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'en');
    });

    test('Updating currency updates SharedPreferences', () async {
      await controller.setCurrency('USD');
      expect(controller.currency.value, 'USD');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('currency'), 'USD');
    });

    test('Updating volume unit updates SharedPreferences', () async {
      await controller.setVolumeUnit('gal');
      expect(controller.volumeUnit.value, 'gal');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('volume_unit'), 'gal');
    });

    test('Updating distance unit updates SharedPreferences', () async {
      await controller.setDistanceUnit('mi');
      expect(controller.distanceUnit.value, 'mi');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('distance_unit'), 'mi');
    });

    test('currencySymbol returns correct symbol', () {
      controller.currency.value = 'USD';
      expect(controller.currencySymbol, '\$');

      controller.currency.value = 'EUR';
      expect(controller.currencySymbol, '€');

      controller.currency.value = 'KZT';
      expect(controller.currencySymbol, '₸');

      controller.currency.value = 'RUB';
      expect(controller.currencySymbol, '₽');

      controller.currency.value = 'GBP';
      expect(controller.currencySymbol, 'GBP');
    });

    group('Volume conversions', () {
      test('convertVolume same units returns original amount', () {
        expect(controller.convertVolume(10, 'L', 'L'), 10);
        expect(controller.convertVolume(10, 'gal', 'gal'), 10);
      });

      test('convertVolume L to gal', () {
        expect(controller.convertVolume(10, 'L', 'gal'), closeTo(2.64172, 0.0001));
      });

      test('convertVolume gal to L', () {
        expect(controller.convertVolume(10, 'gal', 'L'), closeTo(37.8541, 0.0001));
      });

      test('convertVolume ignores kWh', () {
        expect(controller.convertVolume(10, 'kWh', 'L'), 10);
        expect(controller.convertVolume(10, 'L', 'kWh'), 10);
      });
    });

    group('Distance conversions', () {
      test('convertDistance same units returns original distance', () {
        expect(controller.convertDistance(100, 'km', 'km'), 100);
        expect(controller.convertDistance(100, 'mi', 'mi'), 100);
      });

      test('convertDistance km to mi', () {
        expect(controller.convertDistance(100, 'km', 'mi'), closeTo(62.1371, 0.0001));
      });

      test('convertDistance mi to km', () {
        expect(controller.convertDistance(62.1371, 'mi', 'km'), closeTo(100, 0.0001));
      });
    });
  });
}
