import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  static const _cacheKey = 'currency_rates_cache';
  static const _timestampKey = 'currency_rates_timestamp';
  
  Map<String, dynamic>? _rates; // Base: USD

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_timestampKey) ?? 0;
    
    if (cached != null) {
      _rates = jsonDecode(cached) as Map<String, dynamic>;
    }

    // Refresh if older than 24h
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_rates == null || now - timestamp > 24 * 60 * 60 * 1000) {
      await fetchRates();
    }
  }

  Future<void> fetchRates() async {
    try {
      final response = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _rates = data['rates'] as Map<String, dynamic>;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(_rates));
        await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
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

    final ratesMap = _rates ?? fallbackRates;
    
    final fromRate = (ratesMap[fromCurrency] as num?)?.toDouble() ?? fallbackRates[fromCurrency]!;
    final toRate = (ratesMap[toCurrency] as num?)?.toDouble() ?? fallbackRates[toCurrency]!;

    // Convert from -> USD -> to
    final amountInUsd = amount / fromRate;
    return amountInUsd * toRate;
  }
}
