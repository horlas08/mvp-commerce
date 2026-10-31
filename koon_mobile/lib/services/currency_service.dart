import 'package:currency_converter/currency.dart';
import 'package:currency_converter/currency_converter.dart';
import 'package:flutter/material.dart';
import '../app/constants/api_constants.dart';
import 'api_service.dart';

class KoonCurrencyService {
  KoonCurrencyService._();

  static Map<String, double>? _cachedRates;
  static DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 15);

  /// Fetch manual exchange rates from backend config and cache for 15 minutes.
  static Future<Map<String, double>?> getExchangeRates({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedRates != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedRates;
    }

    try {
      final response = await ApiService().dio.get('${ApiConstants.baseUrl}/config/exchange-rates');
      if (response.statusCode == 200 && response.data is Map) {
        final Map<String, dynamic> raw = Map<String, dynamic>.from(response.data);
        final Map<String, double> rates = {};
        raw.forEach((k, v) {
          if (v is num) {
            rates[k.toUpperCase()] = v.toDouble();
          }
        });
        _cachedRates = rates;
        _lastFetchTime = DateTime.now();
        return _cachedRates;
      }
    } catch (e) {
      debugPrint('[currency_service] Failed to fetch exchange rates: $e');
    }
    return _cachedRates;
  }

  static Currency? _detectCurrency(String priceStr) {
    final lower = priceStr.toLowerCase();
    if (lower.contains('\$') || lower.contains('usd')) {
      return Currency.usd;
    } else if (lower.contains('€') || lower.contains('eur')) {
      return Currency.eur;
    } else if (lower.contains('aed') || lower.contains('د.إ')) {
      return Currency.aed;
    } else if (lower.contains('¥') || lower.contains('cny')) {
      return Currency.cny;
    } else if (lower.contains('jpy')) {
      return Currency.jpy;
    } else if (lower.contains('₦') || lower.contains('ngn')) {
      return Currency.ngn;
    } else if (lower.contains('£') || lower.contains('gbp')) {
      return Currency.gbp;
    } else if (lower.contains('sar') || lower.contains('ر.س')) {
      return Currency.sar;
    }
    return null;
  }

  static Future<String> convertToSar(String priceStr) async {
    if (priceStr.isEmpty) return priceStr;

    final currency = _detectCurrency(priceStr);
    if (currency == null || currency == Currency.sar) {
      return priceStr;
    }

    final clean = priceStr.replaceAll(',', '');
    final numRegex = RegExp(r'\d+(?:\.\d+)?');
    final matches = numRegex.allMatches(clean).toList();

    if (matches.isEmpty) return priceStr;

    // 1. Check if backend manual exchange rate exists
    final rates = await getExchangeRates();
    final currencyCode = currency.name.toUpperCase();
    final manualRate = rates?[currencyCode];

    if (manualRate != null) {
      if (matches.length == 1) {
        final amount = double.tryParse(matches[0].group(0) ?? '');
        if (amount != null) {
          final converted = amount * manualRate;
          return '${converted.toStringAsFixed(2)} SAR';
        }
      } else if (matches.length >= 2) {
        final amount1 = double.tryParse(matches[0].group(0) ?? '');
        final amount2 = double.tryParse(matches[1].group(0) ?? '');
        if (amount1 != null && amount2 != null) {
          final converted1 = amount1 * manualRate;
          final converted2 = amount2 * manualRate;
          return '${converted1.toStringAsFixed(2)} - ${converted2.toStringAsFixed(2)} SAR';
        }
      }
    }

    // 2. Fall back to live CurrencyConverter
    try {
      if (matches.length == 1) {
        final amount = double.tryParse(matches[0].group(0) ?? '');
        if (amount != null) {
          final converted = await CurrencyConverter.convert(
            from: currency,
            to: Currency.sar,
            amount: amount,
          );
          if (converted != null) {
            return '${converted.toStringAsFixed(2)} SAR';
          }
        }
      } else if (matches.length >= 2) {
        final amount1 = double.tryParse(matches[0].group(0) ?? '');
        final amount2 = double.tryParse(matches[1].group(0) ?? '');
        if (amount1 != null && amount2 != null) {
          final converted1 = await CurrencyConverter.convert(
            from: currency,
            to: Currency.sar,
            amount: amount1,
          );
          final converted2 = await CurrencyConverter.convert(
            from: currency,
            to: Currency.sar,
            amount: amount2,
          );
          if (converted1 != null && converted2 != null) {
            return '${converted1.toStringAsFixed(2)} - ${converted2.toStringAsFixed(2)} SAR';
          }
        }
      }
    } catch (e) {
      debugPrint('[currency_service] Live conversion failed: $e');
    }

    return priceStr;
  }

  static double parsePriceToDouble(dynamic priceRaw) {
    if (priceRaw == null) return 0.0;
    if (priceRaw is num) return priceRaw.toDouble();
    String str = priceRaw.toString().trim();
    if (str.isEmpty ||
        str.toLowerCase().contains('out of stock') ||
        str.toLowerCase().contains('unknown') ||
        str.contains('غير متوفر')) {
      return 0.0;
    }

    // Convert Arabic / Persian numerals to ASCII
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(arabicDigits[i], '$i').replaceAll(persianDigits[i], '$i');
    }

    // Extract first number match — MUST start with a digit so we don't
    // accidentally match the period inside Arabic currency symbols like "ر.س"
    // which would give us "." → cleaned to "" → 0.0.
    final match = RegExp(r'(\d[\d,.]*)').firstMatch(str);
    if (match == null) return 0.0;

    var numStr = match.group(1)!;

    // Clean leading/trailing dots/commas
    while (numStr.startsWith('.') || numStr.startsWith(',')) {
      numStr = numStr.substring(1);
    }
    while (numStr.endsWith('.') || numStr.endsWith(',')) {
      numStr = numStr.substring(0, numStr.length - 1);
    }
    if (numStr.isEmpty) return 0.0;

    try {
      double? val;
      if (numStr.contains(',') && numStr.contains('.')) {
        if (numStr.lastIndexOf(',') > numStr.lastIndexOf('.')) {
          val = double.tryParse(numStr.replaceAll('.', '').replaceAll(',', '.'));
        } else {
          val = double.tryParse(numStr.replaceAll(',', ''));
        }
      } else if (numStr.contains(',')) {
        final parts = numStr.split(',');
        if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
          val = double.tryParse(numStr.replaceAll(',', ''));
        } else {
          val = double.tryParse(numStr.replaceAll(',', '.'));
        }
      } else if (numStr.contains('.')) {
        final parts = numStr.split('.');
        if (parts.length > 2) {
          val = double.tryParse(numStr.replaceAll('.', ''));
        } else {
          val = double.tryParse(numStr);
        }
      } else {
        val = double.tryParse(numStr);
      }
      return val ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}
