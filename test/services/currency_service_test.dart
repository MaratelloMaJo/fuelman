import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/services/currency_service.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  late CurrencyService service;
  late MockHttpClient mockClient;

  setUp(() {
    service = CurrencyService.instance;
    mockClient = MockHttpClient();
    service.setClient(mockClient);
    service.rates = null;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    service.setClient(null);
    service.rates = null;
  });

  group('CurrencyService Endpoint Security', () {
    test('isSecureEndpoint approves HTTPS and correct host', () {
      expect(
        CurrencyService.isSecureEndpoint(
          Uri.parse('https://open.er-api.com/v6/latest/USD'),
        ),
        isTrue,
      );
    });

    test('isSecureEndpoint rejects insecure HTTP or unknown hosts', () {
      expect(
        CurrencyService.isSecureEndpoint(
          Uri.parse('http://open.er-api.com/v6/latest/USD'),
        ),
        isFalse,
      );
      expect(
        CurrencyService.isSecureEndpoint(
          Uri.parse('https://evil-site.com/v6/latest/USD'),
        ),
        isFalse,
      );
    });
  });

  group('CurrencyService fetchRates and Cache', () {
    test('fetchRates stores rates in memory and SharedPreferences on 200',
        () async {
      final jsonResponse = jsonEncode({
        'result': 'success',
        'rates': {
          'USD': 1.0,
          'EUR': 0.85,
          'RUB': 95.0,
        },
      });

      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(jsonResponse, 200),
      );

      await service.fetchRates();

      expect(service.rates, isNotNull);
      expect(service.rates!['EUR'], 0.85);
      expect(service.rates!['RUB'], 95.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('currency_rates_cache'), isNotNull);
      expect(prefs.getInt('currency_rates_timestamp'), isNotNull);
    });

    test('fetchRates handles non-200 HTTP response gracefully in catch block',
        () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response('Server Error', 500),
      );

      await service.fetchRates();

      // Rates should remain null
      expect(service.rates, isNull);
    });

    test('fetchRates handles network exception gracefully in catch block',
        () async {
      when(() => mockClient.get(any()))
          .thenThrow(http.ClientException('Network down'));

      await service.fetchRates();

      expect(service.rates, isNull);
    });

    test('fetchRates handles malformed JSON gracefully in catch block',
        () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response('<<<not-json>>>', 200),
      );

      await service.fetchRates();

      expect(service.rates, isNull);
    });

    test('fetchRates handles invalid json schema gracefully', () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response('{"rates": "not-a-map"}', 200),
      );

      await service.fetchRates();

      expect(service.rates, isNull);
    });

    test('init() loads cached rates if available', () async {
      final cachedRates = {
        'USD': 1.0,
        'EUR': 0.92,
      };
      final now = DateTime.now().millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'currency_rates_cache': jsonEncode(cachedRates),
        'currency_rates_timestamp': now,
      });

      await service.init();

      expect(service.rates, isNotNull);
      expect(service.rates!['EUR'], 0.92);
      verifyNever(() => mockClient.get(any()));
    });
  });

  group('CurrencyService convert', () {
    test('returns same amount if currencies match', () {
      expect(service.convert(100.0, 'USD', 'USD'), 100.0);
      expect(service.convert(50.0, 'EUR', 'EUR'), 50.0);
    });

    test('converts using loaded rates', () {
      service.rates = {
        'USD': 1.0,
        'EUR': 0.8,
        'RUB': 80.0,
      };

      // 80 RUB -> 1 USD -> 0.8 EUR
      final result = service.convert(80.0, 'RUB', 'EUR');
      expect(result, closeTo(0.8, 0.001));

      // 10 USD -> 8 EUR
      expect(service.convert(10.0, 'USD', 'EUR'), closeTo(8.0, 0.001));
    });

    test('falls back to static rates when custom rates not available', () {
      service.rates = null;

      // Fallback: USD: 1.0, RUB: 90.0, EUR: 0.9
      // 90 RUB -> 1 USD -> 0.9 EUR
      final result = service.convert(90.0, 'RUB', 'EUR');
      expect(result, closeTo(0.9, 0.001));
    });
  });
}
