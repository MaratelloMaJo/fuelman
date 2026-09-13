import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuelman/controllers/theme_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
  });

  test('default theme is system when no preferences exist', () async {
    final controller = ThemeController();
    Get.put(controller);
    await Future.delayed(Duration.zero);

    expect(controller.themeMode, ThemeMode.system);
    expect(controller.isSystem, true);
    expect(controller.isDark, false);

    await Get.delete<ThemeController>();
  });

  test('loads dark mode from preferences', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final controller = ThemeController();
    Get.put(controller);
    await Future.delayed(Duration.zero);

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.isSystem, false);
    expect(controller.isDark, true);

    await Get.delete<ThemeController>();
  });

  test('loads light mode from preferences', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'light'});
    final controller = ThemeController();
    Get.put(controller);
    await Future.delayed(Duration.zero);

    expect(controller.themeMode, ThemeMode.light);
    expect(controller.isSystem, false);
    expect(controller.isDark, false);

    await Get.delete<ThemeController>();
  });

  test('fallback loading using the old isDarkMode boolean preference (true)', () async {
    SharedPreferences.setMockInitialValues({'isDarkMode': true});
    final controller = ThemeController();
    Get.put(controller);
    await Future.delayed(Duration.zero);

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.isSystem, false);
    expect(controller.isDark, true);

    await Get.delete<ThemeController>();
  });

  test('fallback loading using the old isDarkMode boolean preference (false)', () async {
    SharedPreferences.setMockInitialValues({'isDarkMode': false});
    final controller = ThemeController();
    Get.put(controller);
    await Future.delayed(Duration.zero);

    expect(controller.themeMode, ThemeMode.light);
    expect(controller.isSystem, false);
    expect(controller.isDark, false);

    await Get.delete<ThemeController>();
  });

  test('setThemeMode updates themeMode and saves to SharedPreferences', () async {
    final controller = ThemeController();
    Get.put(controller);
    await Future.delayed(Duration.zero);

    await controller.setThemeMode(ThemeMode.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.isDark, true);
    expect(controller.isSystem, false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'dark');

    await controller.setThemeMode(ThemeMode.system);
    expect(controller.themeMode, ThemeMode.system);
    expect(controller.isDark, false);
    expect(controller.isSystem, true);

    expect(prefs.getString('themeMode'), 'system');

    await Get.delete<ThemeController>();
  });
}
