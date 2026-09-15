import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGeolocatorPlatform mockPlatform;
  late GeolocatorPlatform originalPlatform;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    mockPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockPlatform;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  group('LocationService.getCurrentLocation', () {
    test('returns coordinates when GPS enabled and permission is granted',
        () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);

      final mockPosition = Position(
        longitude: 37.6173,
        latitude: 55.7558,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 150.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      when(() => mockPlatform.getCurrentPosition(
            locationSettings: any(named: 'locationSettings'),
          )).thenAnswer((_) async => mockPosition);

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNotNull);
      expect(result!.latitude, 55.7558);
      expect(result.longitude, 37.6173);
    });

    test('returns null when location service is disabled', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => false);

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNull);
      verifyNever(() => mockPlatform.checkPermission());
    });

    test('returns null when permission is deniedForever', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.deniedForever);

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNull);
      verifyNever(() => mockPlatform.requestPermission());
    });

    test('requests permission when denied, returns coordinates if granted',
        () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      when(() => mockPlatform.requestPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);

      final mockPosition = Position(
        longitude: 10.0,
        latitude: 20.0,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      when(() => mockPlatform.getCurrentPosition(
            locationSettings: any(named: 'locationSettings'),
          )).thenAnswer((_) async => mockPosition);

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNotNull);
      expect(result!.latitude, 20.0);
      expect(result.longitude, 10.0);
      verify(() => mockPlatform.requestPermission()).called(1);
    });

    test('returns null when requested permission is still denied', () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      when(() => mockPlatform.requestPermission())
          .thenAnswer((_) async => LocationPermission.denied);

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNull);
    });

    test('catch block returns null on exception during checkPermission',
        () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      when(() => mockPlatform.checkPermission())
          .thenThrow(Exception('Check permission failure'));

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNull);
    });

    test('catch block returns null on exception during getCurrentPosition',
        () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenAnswer((_) async => true);

      when(() => mockPlatform.checkPermission())
          .thenAnswer((_) async => LocationPermission.always);

      when(() => mockPlatform.getCurrentPosition(
            locationSettings: any(named: 'locationSettings'),
          )).thenThrow(Exception('Location hardware failure'));

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNull);
    });

    test(
        'catch block returns null on exception during isLocationServiceEnabled',
        () async {
      when(() => mockPlatform.isLocationServiceEnabled())
          .thenThrow(Exception('Service enabled check failure'));

      final result = await LocationService.instance.getCurrentLocation();

      expect(result, isNull);
    });
  });
}
