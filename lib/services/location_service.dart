import 'package:geolocator/geolocator.dart';

/// Сервис для получения текущего местоположения через GPS.
///
/// Использует пакет [geolocator]. Открытие карт — через [url_launcher].
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Запрашивает разрешение и возвращает текущее местоположение.
  ///
  /// Возвращает null если разрешение отклонено или GPS недоступен.
  Future<({double latitude, double longitude})?> getCurrentLocation() async {
    try {
      // Проверяем, включён ли GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
