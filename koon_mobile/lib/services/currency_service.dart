import 'package:currency_converter/currency.dart';
import 'package:currency_converter/currency_converter.dart';
import 'package:flutter/material.dart';

class KoonCurrencyService {
  KoonCurrencyService._();

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
}
