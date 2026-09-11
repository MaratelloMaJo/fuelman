sed -i 's/ever(vc.selectedVehicle, (_) => _onVehicleChanged());/_subscriptions.add(vc.selectedVehicle.listen((_) => _onVehicleChanged()));/' lib/controllers/fuel_entry_controller.dart
sed -i 's/ever(settings.currency, (_) => _recalcStatsCurrentVehicle());/_subscriptions.add(settings.currency.listen((_) => _recalcStatsCurrentVehicle()));/' lib/controllers/fuel_entry_controller.dart
sed -i 's/ever(settings.volumeUnit, (_) => _recalcStatsCurrentVehicle());/_subscriptions.add(settings.volumeUnit.listen((_) => _recalcStatsCurrentVehicle()));/' lib/controllers/fuel_entry_controller.dart
sed -i '/import..package:get\/get.dart.;/i import '"'"'dart:async'"'"';' lib/controllers/fuel_entry_controller.dart
sed -i '/final anomalousIds = <int>{}.obs;/a \ \ final List<StreamSubscription> _subscriptions = [];' lib/controllers/fuel_entry_controller.dart
sed -i '/void _recalcStatsCurrentVehicle() {/i \ \ @override\n\ \ void onClose() {\n\ \ \ \ for (final sub in _subscriptions) {\n\ \ \ \ \ \ sub.cancel();\n\ \ \ \ }\n\ \ \ \ super.onClose();\n\ \ }\n' lib/controllers/fuel_entry_controller.dart

sed -i 's/ever(_vehicleCtrl.selectedVehicle, (_) => _onVehicleChanged());/_subscriptions.add(_vehicleCtrl.selectedVehicle.listen((_) => _onVehicleChanged()));/' lib/controllers/car_expense_controller.dart
sed -i '/import..package:get\/get.dart.;/i import '"'"'dart:async'"'"';' lib/controllers/car_expense_controller.dart
sed -i '/final _vehicleCtrl = Get.find<VehicleController>();/a \ \ final List<StreamSubscription> _subscriptions = [];' lib/controllers/car_expense_controller.dart
sed -i '/void _onVehicleChanged() {/i \ \ @override\n\ \ void onClose() {\n\ \ \ \ for (final sub in _subscriptions) {\n\ \ \ \ \ \ sub.cancel();\n\ \ \ \ }\n\ \ \ \ super.onClose();\n\ \ }\n' lib/controllers/car_expense_controller.dart

sed -i 's/ever(_vehicleCtrl.selectedVehicle, (_) => _onVehicleChanged());/_subscriptions.add(_vehicleCtrl.selectedVehicle.listen((_) => _onVehicleChanged()));/' lib/controllers/charging_entry_controller.dart
sed -i '/import..package:get\/get.dart.;/i import '"'"'dart:async'"'"';' lib/controllers/charging_entry_controller.dart
sed -i '/final _vehicleCtrl = Get.find<VehicleController>();/a \ \ final List<StreamSubscription> _subscriptions = [];' lib/controllers/charging_entry_controller.dart
sed -i '/void _onVehicleChanged() {/i \ \ @override\n\ \ void onClose() {\n\ \ \ \ for (final sub in _subscriptions) {\n\ \ \ \ \ \ sub.cancel();\n\ \ \ \ }\n\ \ \ \ super.onClose();\n\ \ }\n' lib/controllers/charging_entry_controller.dart
