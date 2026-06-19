import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import '../database/fuel_database.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.find<ThemeController>();
    final settingsCtrl = Get.find<SettingsController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('settings_title'.tr),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // ── Внешний вид ──
          _SectionHeader(title: 'settings_appearance'.tr),
          Obx(() {
            final mode = themeCtrl.themeMode;
            final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && Theme.of(context).brightness == Brightness.dark);
            return ListTile(
              leading: Icon(
                mode == ThemeMode.system
                    ? Icons.brightness_auto_rounded
                    : (mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                color: isDark ? Colors.amber : cs.primary,
              ),
              title: Text('settings_theme'.tr, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<ThemeMode>(
                  value: mode,
                  items: [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('theme_system'.tr)),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('theme_light'.tr)),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('theme_dark'.tr)),
                  ],
                  onChanged: (v) {
                    if (v != null) themeCtrl.setThemeMode(v);
                  },
                ),
              ),
            );
          }),

          const Divider(),
          _SectionHeader(title: 'settings_preferences'.tr),

          // ── Язык ──
          Obx(() => ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text('settings_language'.tr),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settingsCtrl.language.value,
                    items: const [
                      DropdownMenuItem(
                        value: 'ru',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇷🇺 '),
                            Text('Русский'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇬🇧 '),
                            Text('English'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'kk',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇰🇿 '),
                            Text('Қазақша'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) settingsCtrl.setLanguage(v);
                    },
                  ),
                ),
              )),

          // ── Единицы объёма ──
          Obx(() => ListTile(
                leading: const Icon(Icons.water_drop_rounded),
                title: Text('settings_volume_unit'.tr),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settingsCtrl.volumeUnit.value,
                    items: [
                      DropdownMenuItem(value: 'L', child: Text('volume_liters'.tr)),
                      DropdownMenuItem(value: 'gal', child: Text('volume_gallons'.tr)),
                    ],
                    onChanged: (v) {
                      if (v != null) settingsCtrl.setVolumeUnit(v);
                    },
                  ),
                ),
              )),

          // ── Валюта ──
          Obx(() => ListTile(
                leading: const Icon(Icons.sell_rounded),
                title: Text('settings_currency'.tr),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: settingsCtrl.currency.value,
                    items: const [
                      DropdownMenuItem(value: 'RUB', child: Text('RUB (₽)')),
                      DropdownMenuItem(value: 'KZT', child: Text('KZT (₸)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                    ],
                    onChanged: (v) {
                      if (v != null) settingsCtrl.setCurrency(v);
                    },
                  ),
                ),
              )),

          const Divider(),
          _SectionHeader(title: 'settings_data'.tr),

          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: Text('settings_export'.tr),
            subtitle: Text('settings_export_subtitle'.tr),
            onTap: () async {
              await FuelDatabase.instance.exportBackup();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: Text('settings_import'.tr),
            subtitle: Text('settings_import_subtitle'.tr),
            onTap: () async {
              final ok = await FuelDatabase.instance.importBackup();
              if (ok) {
                Get.snackbar(
                  'settings_restore_done'.tr,
                  'settings_restore_msg'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
          ),

          const Divider(),
          _SectionHeader(title: 'settings_about'.tr),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text('settings_version'.tr),
            trailing: Text(_version),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'MaJo Production',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}


// ─────────────────────────────────── Section header ──

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
