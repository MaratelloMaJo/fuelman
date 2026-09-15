import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const _cacheKey = 'currency_rates_cache';
  static const _timestampKey = 'currency_rates_timestamp';

  static final Uri ratesUri = Uri.parse('https://open.er-api.com/v6/latest/USD');

  http.Client? _client;
  Map<String, dynamic>? rates; // Base: USD

  /// Sets a custom [http.Client] (e.g. with custom SecurityContext / pinned certificates or for testing).
  void setClient(http.Client? client) {
    _client = client;
  }

  /// Verifies that the endpoint is HTTPS and points to the allowed API host.
  static bool isSecureEndpoint(Uri uri) {
    return uri.isScheme('https') && uri.host == 'open.er-api.com';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_timestampKey) ?? 0;

    if (cached != null) {
      rates = jsonDecode(cached) as Map<String, dynamic>;
    }

    // Refresh if older than 24h
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rates == null || now - timestamp > 24 * 60 * 60 * 1000) {
      await fetchRates();
    }
  }

  Future<void> fetchRates() async {
    try {
      if (!isSecureEndpoint(ratesUri)) {
        throw const FormatException('Insecure or untrusted endpoint');
      }

      final client = _client ?? http.Client();
      final bool shouldClose = _client == null;
      http.Response response;
      try {
        response = await client
            .get(ratesUri)
            .timeout(const Duration(seconds: 5));
      } finally {
        if (shouldClose) {
          client.close();
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['rates'] is Map) {
          rates = Map<String, dynamic>.from(data['rates'] as Map);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, jsonEncode(rates));
          await prefs.setInt(
              _timestampKey, DateTime.now().millisecondsSinceEpoch);
        }
      }
    } catch (e, stack) {
      developer.log('Ошибка при загрузке курсов валют', error: e, stackTrace: stack, name: 'CurrencyService');
      // Ignored. Fallback to cached rates or fallback static rates if needed.
    }
  }

  double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;

    // Fallback static rates if no data
    final fallbackRates = {
      'USD': 1.0,
      'EUR': 0.9,
      'RUB': 90.0,
      'KZT': 450.0,
    };

    final ratesMap = rates ?? fallbackRates;

    final fromRate = (ratesMap[fromCurrency] as num?)?.toDouble() ??
        fallbackRates[fromCurrency]!;
    final toRate = (ratesMap[toCurrency] as num?)?.toDouble() ??
        fallbackRates[toCurrency]!;

    // Convert from -> USD -> to
    final amountInUsd = amount / fromRate;
    return amountInUsd * toRate;
  }
}
