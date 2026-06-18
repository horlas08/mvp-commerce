import 'dart:convert';
import 'package:get/get.dart';
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
        Get.snackbar('Compare List', 'Product removed from compare list', snackPosition: SnackPosition.BOTTOM);
      }
    } else {
      if (comparedProducts.length >= 4) {
        if (Get.key.currentState != null) {
          Get.snackbar('Compare List', 'You can compare up to 4 products at a time.', snackPosition: SnackPosition.BOTTOM);
        }
        return;
      }
      comparedProducts.add(product);
      if (Get.key.currentState != null) {
        Get.snackbar('Compare List', 'Product added to compare list', snackPosition: SnackPosition.BOTTOM);
      }
    }
    _saveComparedProducts();
  }

  void clearCompareList() {
    comparedProducts.clear();
    _saveComparedProducts();
  }
}
