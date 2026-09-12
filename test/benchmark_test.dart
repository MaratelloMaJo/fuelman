import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/controllers/settings_controller.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Benchmark calculateOverallStats', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    Get.put(SettingsController());

    List<FuelEntry> entries = [];
    for (int i = 0; i < 10000; i++) {
      entries.add(FuelEntry(
        vehicleId: 1,
        date: DateTime.now().subtract(Duration(days: i)),
        odometer: 100000.0 + i * 100,
        volume: 40,
        isFullTank: true,
        pricePerLiter: 50,
        storedTotalCost: 2000,
        entryType: 'fuel',
      ));
    }

    // Warmup
    for(int i = 0; i < 50; i++) {
      FuelEntryController.calculateOverallStats(entries);
    }

    final stopwatch = Stopwatch()..start();
    int iterations = 1000;
    for (int i = 0; i < iterations; i++) {
      FuelEntryController.calculateOverallStats(entries);
    }
    stopwatch.stop();

    print('Average calculateOverallStats time for 10000 entries: ${stopwatch.elapsedMilliseconds / iterations} ms');
  });
}
