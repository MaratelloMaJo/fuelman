🧪 Added tests for NotificationService

🎯 **What:** The `NotificationService` lacked unit tests for its main functionalities (`init`, `requestPermission`, `show`, `cancel`). The test coverage gap has been resolved.
📊 **Coverage:** Mocked `FlutterLocalNotificationsPlugin` and related platform-specific implementation classes (`AndroidFlutterLocalNotificationsPlugin`, `IOSFlutterLocalNotificationsPlugin`) using `mocktail`. Covered initializations, permission requests for Android/iOS/others, and notification show/cancel/cancelAll functionalities.
✨ **Result:** Improved overall test coverage and reliability of the `NotificationService` preventing regressions.
