import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:shared_preferences/shared_preferences.dart';

class CompareController extends GetxController {
  final RxList<Map<String, dynamic>> comparedProducts = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadComparedProducts();
  }

  Future<void> _loadComparedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('compared_products');
      if (cached != null) {
        final List decoded = jsonDecode(cached);
        comparedProducts.value = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _saveComparedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('compared_products', jsonEncode(comparedProducts));
    } catch (_) {}
  }

  bool isComparing(String productId) {
    return comparedProducts.any((p) => p['id'] == productId);
  }

  void toggleCompare(Map<String, dynamic> product) {
    final productId = product['id'];
    if (isComparing(productId)) {
      comparedProducts.removeWhere((p) => p['id'] == productId);
      if (Get.key.currentState != null) {
        Get.snackbar('compare_list'.tr(), 'product_removed_compare'.tr(), snackPosition: SnackPosition.BOTTOM);
      }
    } else {
      if (comparedProducts.length >= 4) {
        if (Get.key.currentState != null) {
          Get.snackbar('compare_list'.tr(), 'compare_limit_reached'.tr(), snackPosition: SnackPosition.BOTTOM);
        }
        return;
      }
      comparedProducts.add(product);
      if (Get.key.currentState != null) {
        Get.snackbar('compare_list'.tr(), 'product_added_compare'.tr(), snackPosition: SnackPosition.BOTTOM);
      }
    }
    _saveComparedProducts();
  }

  void clearCompareList() {
    comparedProducts.clear();
    _saveComparedProducts();
  }
}
