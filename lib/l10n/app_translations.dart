import 'package:get/get.dart';

import 'app_ru.dart';
import 'app_en.dart';
import 'app_kk.dart';

/// Объединённые переводы FuelMan.
///
/// Использование: передать в [GetMaterialApp.translations].
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        ...AppTranslationsRu().keys,
        ...AppTranslationsEn().keys,
        ...AppTranslationsKk().keys,
      };
}
