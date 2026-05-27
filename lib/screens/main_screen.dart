import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/vehicle_controller.dart';
import 'home_tab.dart';
import 'history_tab.dart';
import 'statistics_tab.dart';
import 'vehicles_tab.dart';

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
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Главная',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: false,
                child: const Icon(Icons.history_outlined),
              ),
              selectedIcon: const Icon(Icons.history_rounded),
              label: 'История',
            ),
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Статистика',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: !hasVehicles && _index != 3,
                child: const Icon(Icons.garage_outlined),
              ),
              selectedIcon: const Icon(Icons.garage_rounded),
              label: 'Гараж',
            ),
          ],
        );
      }),
    );
  }
}
