import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koon_mobile/controllers/settings_controller.dart';
import 'package:koon_mobile/controllers/compare_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsController Tests', () {
    test('Default values are correct', () {
      final controller = Get.put(SettingsController());
      expect(controller.currentCurrency.value, 'SAR');
      expect(controller.isDarkMode.value, false);
      Get.delete<SettingsController>();
    });

    test('Currency conversion SAR -> USD works correctly', () async {
      final controller = Get.put(SettingsController());
      
      // Default formatting: price 10.0 in SAR
      expect(controller.formatPrice(10.0, 'SAR'), '10.00 SAR');

      // Set currency to USD
      await controller.setCurrency('USD');
      expect(controller.currentCurrency.value, 'USD');

      // 10.00 SAR divided by 3.75 should be 2.67 USD
      expect(controller.formatPrice(10.0, 'SAR'), '\$2.67');

      Get.delete<SettingsController>();
    });

    test('Theme toggling works', () async {
      final controller = Get.put(SettingsController());
      expect(controller.isDarkMode.value, false);

      await controller.toggleTheme();
      expect(controller.isDarkMode.value, true);

      Get.delete<SettingsController>();
    });
  });

  group('CompareController Tests', () {
    test('Adding and removing comparison products works', () {
      final controller = Get.put(CompareController());
      final product = {'id': 'prod-1', 'title': 'Product 1', 'price': 100.0};

      expect(controller.isComparing('prod-1'), false);

      // Add to compare list
      controller.toggleCompare(product);
      expect(controller.isComparing('prod-1'), true);
      expect(controller.comparedProducts.length, 1);

      // Remove from compare list
      controller.toggleCompare(product);
      expect(controller.isComparing('prod-1'), false);
      expect(controller.comparedProducts.isEmpty, true);

      Get.delete<CompareController>();
    });

    test('Compare list size limit (max 4) is enforced', () {
      final controller = Get.put(CompareController());

      // Add 4 products
      for (int i = 1; i <= 4; i++) {
        controller.toggleCompare({'id': 'prod-$i', 'title': 'Product $i'});
      }
      expect(controller.comparedProducts.length, 4);

      // Try adding 5th product
      controller.toggleCompare({'id': 'prod-5', 'title': 'Product 5'});
      expect(controller.comparedProducts.length, 4); // should still be 4
      expect(controller.isComparing('prod-5'), false);

      Get.delete<CompareController>();
    });
  });
}
