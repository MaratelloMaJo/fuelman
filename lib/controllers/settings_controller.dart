import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends GetxController {
  final _prefs = SharedPreferences.getInstance();

  final language = 'ru'.obs;
  final currency = 'RUB'.obs;
  final volumeUnit = 'L'.obs;
  final distanceUnit = 'km'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final p = await _prefs;
    language.value = p.getString('language') ?? 'ru';
    currency.value = p.getString('currency') ?? 'RUB';
    volumeUnit.value = p.getString('volume_unit') ?? 'L';
    distanceUnit.value = p.getString('distance_unit') ?? 'km';
  }

  Future<void> setLanguage(String val) async {
    language.value = val;
    (await _prefs).setString('language', val);
    // Map language code to full locale
    final localeMap = <String, Locale>{
      'ru': const Locale('ru', 'RU'),
      'en': const Locale('en', 'US'),
      'kk': const Locale('kk', 'KZ'),
    };
    Get.updateLocale(localeMap[val] ?? Locale(val));
  }

  Future<void> setCurrency(String val) async {
    currency.value = val;
    (await _prefs).setString('currency', val);
  }

  Future<void> setVolumeUnit(String val) async {
    volumeUnit.value = val;
    (await _prefs).setString('volume_unit', val);
  }

  Future<void> setDistanceUnit(String val) async {
    distanceUnit.value = val;
    (await _prefs).setString('distance_unit', val);
  }

  String get currencySymbol {
    switch (currency.value) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'KZT': return '₸';
      case 'RUB':
      default:
        return '₽';
    }
  }

  /// Конвертация объёма в целевую единицу
  double convertVolume(double amount, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return amount;
    if (fromUnit == 'kWh' || toUnit == 'kWh') return amount; // Не конвертируем электричество в литры

    if (fromUnit == 'L' && toUnit == 'gal') return amount * 0.264172;
    if (fromUnit == 'gal' && toUnit == 'L') return amount / 0.264172;
    return amount;
  }

  /// Конвертация расстояния
  double convertDistance(double distance, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return distance;
    if (fromUnit == 'km' && toUnit == 'mi') return distance * 0.621371;
    if (fromUnit == 'mi' && toUnit == 'km') return distance / 0.621371;
    return distance;
  }
}
