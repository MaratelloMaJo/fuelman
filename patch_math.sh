sed -i 's/if (distance > 0 && distance.isFinite)/if (distance > 0 \&\& distance.isFinite \&\& !distance.isNaN)/g' lib/controllers/fuel_entry_controller.dart
