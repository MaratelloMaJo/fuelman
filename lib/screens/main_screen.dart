import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/vehicle_controller.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'statistics_tab.dart';
import 'vehicles_tab.dart';
import 'settings_tab.dart';

/// Корневой экран с нижней навигацией Material 3.
///
/// Использует [IndexedStack] для сохранения состояния каждой вкладки
/// при переключении (прокрутка не теряется).
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  // IndexedStack сохраняет состояние всех вкладок одновременно.
  static const _tabs = [
    HomeTab(),
    HistoryTab(),
    StatisticsTab(),
    VehiclesTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Obx(() {
        final vehicleCtrl = Get.find<VehicleController>();
        final hasVehicles = vehicleCtrl.vehicles.isNotEmpty;

        return NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: 'nav_home'.tr,
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: false,
                child: const Icon(Icons.history_outlined),
              ),
              selectedIcon: const Icon(Icons.history_rounded),
              label: 'nav_history'.tr,
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
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: 'nav_settings'.tr,
            ),
          ],
        );
      }),
    );
  }
}
