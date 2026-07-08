import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:shared_preferences/shared_preferences.dart';
import '../app/theme/app_theme.dart';

class SettingsController extends GetxController {
  final RxString currentCurrency = 'SAR'.obs;
  final RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
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
    // 1. Normalize the original price to USD first
    double priceInUsd = 0.0;
    final origUpper = originalCurrency.toUpperCase().trim();
    if (origUpper == 'USD' || origUpper == '\$') {
      priceInUsd = price;
    } else if (origUpper == 'SAR' || origUpper == 'SR') {
      priceInUsd = price / 3.75;
    } else if (origUpper == 'YER_OLD' || origUpper == 'YER') {
      priceInUsd = price / 530.0;
    } else if (origUpper == 'YER_NEW') {
      priceInUsd = price / 1850.0;
    } else {
      // Fallback: assume SAR
      priceInUsd = price / 3.75;
    }

    // 2. Convert from USD to the current selected currency
    if (currentCurrency.value == 'USD') {
      return '\$${priceInUsd.toStringAsFixed(2)}';
    } else if (currentCurrency.value == 'YER_OLD') {
      final converted = priceInUsd * 530.0;
      return '${converted.toStringAsFixed(0)} ' + 'YER_OLD'.tr();
    } else if (currentCurrency.value == 'YER_NEW') {
      final converted = priceInUsd * 1850.0;
      return '${converted.toStringAsFixed(0)} ' + 'YER_NEW'.tr();
    } else {
      // default is SAR
      final converted = priceInUsd * 3.75;
      return '${converted.toStringAsFixed(2)} ' + 'SAR'.tr();
    }
  }
}
