import 'package:get/get.dart';
import '../services/cart_service.dart';

class CartController extends GetxController {
  final CartService _cartService = CartService();

  final RxString selectedCartType = 'internal'.obs;
  final RxList<Map<String, dynamic>> cartItems = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt totalCartCount = 0.obs;

  final List<Map<String, String>> cartTypes = [
    {'key': 'internal', 'label_en': 'Internal Cart', 'label_ar': 'السلة الداخلية'},
    {'key': 'amazon', 'label_en': 'Amazon Cart', 'label_ar': 'سلة أمازون'},
    {'key': 'aliexpress', 'label_en': 'AliExpress Cart', 'label_ar': 'سلة علي إكسبريس'},
    {'key': 'shein', 'label_en': 'Shein Cart', 'label_ar': 'سلة شي إن'},
    {'key': 'alibaba', 'label_en': 'Alibaba Cart', 'label_ar': 'سلة علي بابا'},
  ];

  @override
  void onInit() {
    super.onInit();
    loadCart();
    ever(selectedCartType, (_) => loadCart());
  }

  Future<void> loadCart() async {
    isLoading.value = true;
    final lang = Get.locale?.languageCode ?? 'en';
    cartItems.value = await _cartService.getCart(cartType: selectedCartType.value, lang: lang);
    isLoading.value = false;
    _refreshTotalCount();
  }

  Future<void> _refreshTotalCount() async {
    // Get total count across all cart types
    final lang = Get.locale?.languageCode ?? 'en';
    final allItems = await _cartService.getCart(lang: lang);
    totalCartCount.value = allItems.length;
  }

  Future<bool> addToCart({
    required String cartType,
    String? productId,
    String? title,
    String? price,
    String? imageUrl,
    String? externalUrl,
    String? siteName,
    int quantity = 1,
  }) async {
    final result = await _cartService.addToCart(
      cartType: cartType,
      productId: productId,
      title: title,
      price: price,
      imageUrl: imageUrl,
      externalUrl: externalUrl,
      siteName: siteName,
      quantity: quantity,
    );
    if (result != null) {
      await loadCart();
      return true;
    }
    return false;
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final success = await _cartService.updateCartItem(itemId, quantity: quantity);
    if (success) await loadCart();
  }

  Future<void> toggleSelection(String itemId, bool isSelected) async {
    final success = await _cartService.updateCartItem(itemId, isSelected: isSelected);
    if (success) await loadCart();
  }

  Future<void> removeItem(String itemId) async {
    final success = await _cartService.removeFromCart(itemId);
    if (success) await loadCart();
  }

  Future<void> clearCurrentCart() async {
    final success = await _cartService.clearCart(cartType: selectedCartType.value);
    if (success) await loadCart();
  }

  double get totalAmount {
    double total = 0;
    for (var item in cartItems) {
      if (item['is_selected'] == true) {
        final priceStr = item['price']?.toString() ?? item['product']?['price']?.toString() ?? '0';
        final price = double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final qty = item['quantity'] ?? 1;
        total += price * qty;
      }
    }
    return total;
  }
}
