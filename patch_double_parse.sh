sed -i "s/double.parse(_volumeCtrl.text.replaceAll(',', '.'))/(double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0.0)/g" lib/screens/add_entry_screen.dart
sed -i "s/double.parse(_odometerCtrl.text.replaceAll(',', '.'))/(double.tryParse(_odometerCtrl.text.replaceAll(',', '.')) ?? 0.0)/g" lib/screens/add_entry_screen.dart
sed -i "s/double.parse(_amountCtrl.text.replaceAll(',', '.'))/(double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0)/g" lib/screens/add_expense_screen.dart
sed -i "s/double.parse(_odometerCtrl.text.replaceAll(',', '.'))/(double.tryParse(_odometerCtrl.text.replaceAll(',', '.')) ?? 0.0)/g" lib/screens/add_charging_screen.dart
sed -i "s/double.parse(_kwhCtrl.text.replaceAll(',', '.'))/(double.tryParse(_kwhCtrl.text.replaceAll(',', '.')) ?? 0.0)/g" lib/screens/add_charging_screen.dart
