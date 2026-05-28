import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Контроллер темы с поддержкой системной темы.
class ThemeController extends GetxController {
  static const _prefsKey = 'themeMode';

  final _themeMode = ThemeMode.system.obs;

  ThemeMode get themeMode => _themeMode.value;

  bool get isDark => _themeMode.value == ThemeMode.dark;
  bool get isSystem => _themeMode.value == ThemeMode.system;

  @override
  void onInit() {
    super.onInit();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_prefsKey);
    if (savedMode == 'dark') {
      _themeMode.value = ThemeMode.dark;
    } else if (savedMode == 'light') {
      _themeMode.value = ThemeMode.light;
    } else {
      _themeMode.value = ThemeMode.system;
    }
    // Обратная совместимость
    if (savedMode == null) {
      final oldIsDark = prefs.getBool('isDarkMode');
      if (oldIsDark != null) {
        _themeMode.value = oldIsDark ? ThemeMode.dark : ThemeMode.light;
      }
    }
    _applyTheme();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode.value = mode;
    _applyTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  void _applyTheme() {
    Get.changeThemeMode(_themeMode.value);
  }
}
