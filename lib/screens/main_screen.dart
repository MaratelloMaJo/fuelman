import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/vehicle_controller.dart';
import 'add_entry_screen.dart';
import 'add_expense_screen.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'statistics_tab.dart';
import 'vehicles_tab.dart';

/// Корневой экран с нижней навигацией Material 3.
///
/// Навигация: Главная / История / [+] / Статистика / Гараж
/// Настройки — кнопка в правом верхнем углу AppBar.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  // Реальные экраны без кнопки + (она в центре не переключает индекс)
  static const _tabs = [
    HomeTab(),
    HistoryTab(),
    StatisticsTab(),
    VehiclesTab(),
  ];

  // Маппинг: NavBar index → tab index
  // 0=Home 1=History 2=(+) 3=Stats 4=Garage
  // В _index храним 0-3 (реальные вкладки), + обрабатывается отдельно
  int _navBarToTabIndex(int navIdx) {
    if (navIdx < 2) return navIdx;
    if (navIdx > 2) return navIdx - 1;
    return _index; // нажата + — индекс не меняется
  }

  int _tabToNavBarIndex(int tabIdx) {
    if (tabIdx < 2) return tabIdx;
    return tabIdx + 1; // сдвиг на 1 из-за центральной кнопки
  }

  void _onNavTap(int navIdx) {
    if (navIdx == 2) {
      _showAddModal();
    } else {
      setState(() => _index = _navBarToTabIndex(navIdx));
    }
  }

  void _showAddModal() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surface.withAlpha(220)
                    : cs.surface.withAlpha(245),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : cs.primary.withAlpha(30),
                    width: 1,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'add_what'.tr,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _AddOptionTile(
                      icon: Icons.local_gas_station_rounded,
                      color: cs.primary,
                      title: 'add_fuel_entry'.tr,
                      subtitle: 'add_fuel_subtitle'.tr,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Get.to(() => const AddEntryScreen());
                      },
                    ),
                    const SizedBox(height: 12),
                    _AddOptionTile(
                      icon: Icons.build_rounded,
                      color: Colors.orange,
                      title: 'add_car_expense'.tr,
                      subtitle: 'add_expense_subtitle'.tr,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Get.to(() => const AddExpenseScreen());
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // контент идёт под NavigationBar
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Obx(() {
        final vehicleCtrl = Get.find<VehicleController>();
        final hasVehicles = vehicleCtrl.vehicles.isNotEmpty;
        final navIdx = _tabToNavBarIndex(_index);

        // Liquid Glass NavigationBar
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          cs.surface.withAlpha(185),
                          cs.surface.withAlpha(210),
                        ]
                      : [
                          cs.surface.withAlpha(215),
                          cs.surface.withAlpha(240),
                        ],
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(18)
                        : cs.primary.withAlpha(25),
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: navIdx,
                onDestinationSelected: _onNavTap,
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: cs.primary.withAlpha(isDark ? 35 : 25),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded,
                        color: cs.primary),
                    label: 'nav_home'.tr,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history_rounded,
                        color: cs.primary),
                    label: 'nav_history'.tr,
                  ),

                  // ── Центральная кнопка + ──
                  NavigationDestination(
                    icon: _GlassPlusButton(cs: cs, isDark: isDark),
                    label: '',
                  ),

                  NavigationDestination(
                    icon: const Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart_rounded,
                        color: cs.primary),
                    label: 'nav_statistics'.tr,
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible:
                          !hasVehicles && _index != 3,
                      child: const Icon(Icons.garage_outlined),
                    ),
                    selectedIcon: Icon(Icons.garage_rounded,
                        color: cs.primary),
                    label: 'nav_garage'.tr,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────── Glass Plus Button ──

class _GlassPlusButton extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _GlassPlusButton({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withAlpha(isDark ? 100 : 80),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withAlpha(60),
          width: 1,
        ),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
    );
  }
}

// ─────────────────────────── Add Option Tile ──

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
