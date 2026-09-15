cat << 'INNEREOF' > patch.diff
--- lib/services/notification_service.dart
+++ lib/services/notification_service.dart
@@ -19,7 +19,7 @@
     _instance = mock ?? NotificationService._();
   }

-  late final FlutterLocalNotificationsPlugin _plugin;
+  final FlutterLocalNotificationsPlugin _plugin;

   bool _initialized = false;
INNEREOF
patch -p0 < patch.diff
