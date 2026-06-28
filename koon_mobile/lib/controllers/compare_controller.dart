import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:shared_preferences/shared_preferences.dart';
import '../app/utils/app_snackbar.dart';

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
      AppSnackbar.info(null, 'product_removed_compare'.tr(), icon: Icons.compare_arrows_rounded);
    } else {
      if (comparedProducts.length >= 4) {
        AppSnackbar.warning(null, 'compare_limit_reached'.tr());
        return;
      }
      comparedProducts.add(product);
      AppSnackbar.success(null, 'product_added_compare'.tr());
    }
    _saveComparedProducts();
  }

  void clearCompareList() {
    comparedProducts.clear();
    _saveComparedProducts();
  }
}
