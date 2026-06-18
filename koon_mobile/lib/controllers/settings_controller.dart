import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    if (currentCurrency.value == 'USD' && originalCurrency == 'SAR') {
      // 1 USD = 3.75 SAR
      final converted = price / 3.75;
      return '\$${converted.toStringAsFixed(2)}';
    } else if (currentCurrency.value == 'SAR' && originalCurrency == 'USD') {
      final converted = price * 3.75;
      return '${converted.toStringAsFixed(2)} SAR';
    } else {
      // display original currency format
      if (originalCurrency == 'USD') {
        return '\$${price.toStringAsFixed(2)}';
      }
      return '${price.toStringAsFixed(2)} SAR';
    }
  }
}
