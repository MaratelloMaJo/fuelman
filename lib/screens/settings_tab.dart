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
      _version = '${info.version}+${info.buildNumber}';
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
            final isDark = themeCtrl.isDark;
            return ListTile(
              leading: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  key: ValueKey(isDark),
                  color: isDark ? Colors.amber : cs.primary,
                ),
              ),
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isDark ? 'settings_dark_theme'.tr : 'settings_light_theme'.tr,
                    key: ValueKey(isDark),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              trailing: _ThemeSwitch(
                value: isDark,
                onChanged: (_) => themeCtrl.toggleTheme(),
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

// ─────────────────────────────────── Theme Switch ──

class _ThemeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ThemeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 56,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? const Color(0xFF1A1A2E) : cs.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: value
                  ? Colors.black.withValues(alpha: 0.3)
                  : cs.primary.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Stack(
          children: [
            // Stars (dark mode)
            AnimatedOpacity(
              opacity: value ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Center(
                  child: Text('✦', style: TextStyle(fontSize: 9, color: Colors.white54)),
                ),
              ),
            ),
            // Sun (light mode)
            AnimatedOpacity(
              opacity: value ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text('☀',
                      style: TextStyle(fontSize: 12, color: cs.primary)),
                ),
              ),
            ),
            // Thumb
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.amber : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: Center(
                  child: Icon(
                    value ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    size: 14,
                    color: value ? const Color(0xFF1A1A2E) : Colors.orange,
                  ),
                ),
              ),
            ),
          ],
        ),
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
