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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 20),
              _AddOptionTile(
                icon: Icons.local_gas_station_rounded,
                color: cs.primary,
                title: 'add_fuel_entry'.tr,
                subtitle: 'Заправка или зарядка',
                onTap: () {
                  Navigator.pop(ctx);
                  Get.to(() => const AddEntryScreen());
                },
              ),
              const SizedBox(height: 12),
              _AddOptionTile(
                icon: Icons.build_rounded,
                color: Colors.orange,
                title: 'add_car_expense'.tr,
                subtitle: 'Сервис, масло, мойка, налог…',
                onTap: () {
                  Navigator.pop(ctx);
                  Get.to(() => const AddExpenseScreen());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Obx(() {
        final vehicleCtrl = Get.find<VehicleController>();
        final hasVehicles = vehicleCtrl.vehicles.isNotEmpty;
        final navIdx = _tabToNavBarIndex(_index);

        return NavigationBar(
          selectedIndex: navIdx,
          onDestinationSelected: _onNavTap,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: 'nav_home'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history_rounded),
              label: 'nav_history'.tr,
            ),

            // ── Центральная кнопка + ──
            NavigationDestination(
              icon: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
              label: '',
            ),

            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart_rounded),
              label: 'nav_statistics'.tr,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: !hasVehicles && _index != 3,
                child: const Icon(Icons.garage_outlined),
              ),
              selectedIcon: const Icon(Icons.garage_rounded),
              label: 'nav_garage'.tr,
            ),
          ],
        );
      }),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
