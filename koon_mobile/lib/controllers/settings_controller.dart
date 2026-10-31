import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:shared_preferences/shared_preferences.dart';
import '../app/theme/app_theme.dart';
import '../services/api_service.dart';
import '../app/constants/api_constants.dart';

class SettingsController extends GetxController {
  final RxString currentCurrency = 'SAR'.obs;
  final RxBool isDarkMode = false.obs;

  final RxMap<String, double> exchangeRates = <String, double>{
    'SAR': 1.0,
    'USD': 3.75,
    'YER_OLD': 530.0,
    'YER_NEW': 1850.0,
    'EUR': 4.10,
    'AED': 1.02,
    'CNY': 0.52,
    'GBP': 4.75,
  }.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    fetchExchangeRates();
  }

  Future<void> fetchExchangeRates() async {
    try {
      final response = await ApiService().dio.get('${ApiConstants.baseUrl}/config/exchange-rates');
      if (response.statusCode == 200 && response.data is Map) {
        final Map<String, dynamic> raw = Map<String, dynamic>.from(response.data);
        raw.forEach((k, v) {
          if (v is num) {
            exchangeRates[k.toUpperCase()] = v.toDouble();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    currentCurrency.value = prefs.getString('currency') ?? 'SAR';
    isDarkMode.value = prefs.getBool('dark_mode') ?? false;

    // Apply saved theme mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.changeTheme(isDarkMode.value ? AppTheme.darkTheme : AppTheme.lightTheme);
    });
  }

  Future<void> setCurrency(String currency) async {
    currentCurrency.value = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
  }

  Future<void> toggleTheme() async {
    isDarkMode.toggle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDarkMode.value);
    Get.changeTheme(isDarkMode.value ? AppTheme.darkTheme : AppTheme.lightTheme);
  }

  String formatPrice(double price, String originalCurrency) {
    final double usdPerSar = exchangeRates['USD'] ?? 3.75;
    final double yerOldPerUsd = exchangeRates['YER_OLD'] ?? 530.0;
    final double yerNewPerUsd = exchangeRates['YER_NEW'] ?? 1850.0;
    final double eurRate = exchangeRates['EUR'] ?? 4.10;
    final double aedRate = exchangeRates['AED'] ?? 1.02;
    final double cnyRate = exchangeRates['CNY'] ?? 0.52;
    final double gbpRate = exchangeRates['GBP'] ?? 4.75;

    // 1. Normalize the original price to USD first
    double priceInUsd = 0.0;
    final origUpper = originalCurrency.toUpperCase().trim();
    if (origUpper == 'USD' || origUpper == '\$') {
      priceInUsd = price;
    } else if (origUpper == 'SAR' || origUpper == 'SR') {
      priceInUsd = price / usdPerSar;
    } else if (origUpper == 'YER_OLD' || origUpper == 'YER') {
      priceInUsd = price / yerOldPerUsd;
    } else if (origUpper == 'YER_NEW') {
      priceInUsd = price / yerNewPerUsd;
    } else if (origUpper == 'EUR' || origUpper == '€') {
      priceInUsd = (price * eurRate) / usdPerSar;
    } else if (origUpper == 'AED' || origUpper == 'د.إ') {
      priceInUsd = (price * aedRate) / usdPerSar;
    } else if (origUpper == 'CNY' || origUpper == '¥') {
      priceInUsd = (price * cnyRate) / usdPerSar;
    } else if (origUpper == 'GBP' || origUpper == '£') {
      priceInUsd = (price * gbpRate) / usdPerSar;
    } else {
      // Fallback: assume SAR
      priceInUsd = price / usdPerSar;
    }

    // 2. Convert from USD to the current selected currency
    if (currentCurrency.value == 'USD') {
      return '\$${priceInUsd.toStringAsFixed(2)}';
    } else if (currentCurrency.value == 'YER_OLD') {
      final converted = priceInUsd * yerOldPerUsd;
      return '${converted.toStringAsFixed(0)} ' + 'YER_OLD'.tr();
    } else if (currentCurrency.value == 'YER_NEW') {
      final converted = priceInUsd * yerNewPerUsd;
      return '${converted.toStringAsFixed(0)} ' + 'YER_NEW'.tr();
    } else {
      // default is SAR
      final converted = priceInUsd * usdPerSar;
      return '${converted.toStringAsFixed(2)} ' + 'SAR'.tr();
    }
  }
}
