import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Контроллер темы (светлая / тёмная) с сохранением выбора.
class ThemeController extends GetxController {
  static const _prefsKey = 'isDarkMode';

  final _isDark = false.obs;

  bool get isDark => _isDark.value;

  ThemeMode get themeMode => _isDark.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark.value = prefs.getBool(_prefsKey) ?? false;
    _applyTheme();
  }

  Future<void> toggleTheme() async {
    _isDark.value = !_isDark.value;
    _applyTheme();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, _isDark.value);
  }

  void _applyTheme() {
    Get.changeThemeMode(_isDark.value ? ThemeMode.dark : ThemeMode.light);
  }
}
