import 'package:get/get.dart';

import '../database/fuel_database.dart';
import '../models/vehicle.dart';

/// Управляет списком автомобилей и выбором активного авто.
class VehicleController extends GetxController {
  final vehicles = <Vehicle>[].obs;
  final selectedVehicle = Rx<Vehicle?>(null);
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadVehicles();
  }

  Future<void> loadVehicles() async {
    isLoading.value = true;
    try {
      final list = await FuelDatabase.instance.getVehicles();
      vehicles.assignAll(list);

      // Восстанавливаем выбранное авто или выбираем первое.
      if (selectedVehicle.value == null && list.isNotEmpty) {
        selectedVehicle.value = list.first;
      } else if (selectedVehicle.value != null) {
        // Обновляем данные выбранного авто (мог измениться).
        final updated = list.firstWhereOrNull(
          (v) => v.id == selectedVehicle.value!.id,
        );
        selectedVehicle.value = updated ?? (list.isNotEmpty ? list.first : null);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    final saved = await FuelDatabase.instance.insertVehicle(vehicle);
    vehicles.add(saved);
    vehicles.sort((a, b) => a.name.compareTo(b.name));
    // Автоматически выбираем только что добавленный автомобиль.
    selectedVehicle.value = saved;
    return saved;
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    await FuelDatabase.instance.updateVehicle(vehicle);
    final index = vehicles.indexWhere((v) => v.id == vehicle.id);
    if (index != -1) vehicles[index] = vehicle;
    if (selectedVehicle.value?.id == vehicle.id) {
      selectedVehicle.value = vehicle;
    }
  }

  Future<void> deleteVehicle(int id) async {
    await FuelDatabase.instance.deleteVehicle(id);
    vehicles.removeWhere((v) => v.id == id);
    if (selectedVehicle.value?.id == id) {
      selectedVehicle.value = vehicles.isNotEmpty ? vehicles.first : null;
    }
  }

  void selectVehicle(Vehicle vehicle) {
    selectedVehicle.value = vehicle;
  }
}
