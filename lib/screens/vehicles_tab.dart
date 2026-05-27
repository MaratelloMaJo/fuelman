import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/vehicle_controller.dart';
import '../widgets/empty_state.dart';
import '../widgets/vehicle_card.dart';
import 'add_vehicle_screen.dart';

/// Вкладка управления автомобилями (гараж).
///
/// Позволяет:
///   — Просматривать список авто
///   — Выбирать активный автомобиль
///   — Добавлять / редактировать / удалять автомобили
class VehiclesTab extends StatelessWidget {
  const VehiclesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleCtrl = Get.find<VehicleController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Гараж'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vehicles_fab',
        onPressed: () => Get.to(() => const AddVehicleScreen()),
        icon: const Icon(Icons.add_rounded),
        label: Text('add_vehicle_fab'.tr),
      ),
      body: Obx(() {
        final vehicles = vehicleCtrl.vehicles;
        final selected = vehicleCtrl.selectedVehicle.value;

        if (vehicles.isEmpty) {
          return EmptyState(
            icon: Icons.garage_rounded,
            title: 'garage_empty_title'.tr,
            subtitle: 'garage_empty_subtitle'.tr,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: vehicles.length,
          itemBuilder: (_, i) {
            final v = vehicles[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VehicleCard(
                vehicle: v,
                isSelected: selected?.id == v.id,
                onTap: () => vehicleCtrl.selectVehicle(v),
                onEdit: () =>
                    Get.to(() => AddVehicleScreen(editVehicle: v)),
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Удалить автомобиль?'),
                      content: Text(
                        'Будут удалены все ${v.name} записи о заправках. '
                        'Это действие нельзя отменить.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('Удалить'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await vehicleCtrl.deleteVehicle(v.id!);
                  }
                },
              ),
            );
          },
        );
      }),
    );
  }
}
