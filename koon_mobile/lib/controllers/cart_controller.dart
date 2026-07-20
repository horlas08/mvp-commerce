import 'dart:async';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import '../services/cart_service.dart';
import '../services/currency_service.dart';

enum AddToCartStatus {
  success,
  unauthorized,
  error,
}

class CartController extends GetxController {
  final CartService _cartService = CartService();

  final RxString selectedCartType = 'internal'.obs;
  final RxList<Map<String, dynamic>> cartItems = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt totalCartCount = 0.obs;

  // ── Cart Auto-Update Refresh States & Queue ─────────────────────────────
  final RxList<Map<String, dynamic>> refreshQueue = <Map<String, dynamic>>[].obs;
  final RxMap<String, String> itemStatuses = <String, String>{}.obs;
  final RxMap<String, String> itemUpdatedPrices = <String, String>{}.obs;
  final Rxn<Map<String, dynamic>> currentRefreshItem = Rxn<Map<String, dynamic>>();
  Timer? _refreshTimeout;

  final List<Map<String, String>> cartTypes = [
    {'key': 'internal', 'label_en': 'Internal Cart', 'label_ar': 'السلة الداخلية'},
    {'key': 'amazon', 'label_en': 'Amazon Cart', 'label_ar': 'سلة أمازون'},
    {'key': 'aliexpress', 'label_en': 'AliExpress Cart', 'label_ar': 'سلة علي إكسبريس'},
    {'key': 'shein', 'label_en': 'Shein Cart', 'label_ar': 'سلة شي إن'},
    {'key': 'alibaba', 'label_en': 'Alibaba Cart', 'label_ar': 'سلة علي بابا'},
    {'key': 'iherb', 'label_en': 'iHerb Cart', 'label_ar': 'سلة آي هيرب'},
  ];

  @override
  void onInit() {
    super.onInit();
    loadCart();
    ever(selectedCartType, (_) => loadCart());
  }

  @override
  void onClose() {
    _refreshTimeout?.cancel();
    super.onClose();
  }

  Future<void> loadCart() async {
    isLoading.value = true;
    final lang = Get.locale?.languageCode ?? 'en';
    cartItems.value = await _cartService.getCart(cartType: selectedCartType.value, lang: lang);
    isLoading.value = false;
    _refreshTotalCount();

    if (selectedCartType.value != 'internal') {
      startCartRefresh();
    }
  }

  void startCartRefresh() {
    _refreshTimeout?.cancel();
    refreshQueue.clear();
    itemStatuses.clear();
    itemUpdatedPrices.clear();
    currentRefreshItem.value = null;

    final externalItems = cartItems.where((item) {
      final extUrl = item['external_url']?.toString() ?? '';
      return extUrl.isNotEmpty;
    }).toList();

    if (externalItems.isEmpty) return;

    for (var item in externalItems) {
      itemStatuses[item['id']] = 'pending';
    }
    refreshQueue.addAll(externalItems);
    _nextQueueItem();
  }

  void _nextQueueItem() {
    _refreshTimeout?.cancel();
    if (refreshQueue.isEmpty) {
      currentRefreshItem.value = null;
      return;
    }
    final item = refreshQueue.removeAt(0);
    currentRefreshItem.value = item;
    itemStatuses[item['id']] = 'updating';

    _refreshTimeout = Timer(const Duration(seconds: 15), () {
      if (currentRefreshItem.value?['id'] == item['id']) {
        Get.log("Timeout refreshing cart item ${item['id']}");
        onRefreshFailed(item['id']);
      }
    });
  }

  void onRefreshComplete(String itemId, String? newPrice, {bool outOfStock = false}) async {
    _refreshTimeout?.cancel();
    if (outOfStock) {
      itemStatuses[itemId] = 'out_of_stock';
      await updateItemPrice(itemId, "Out of Stock");
    } else if (newPrice != null && newPrice.isNotEmpty && !newPrice.toLowerCase().contains('unknown')) {
      final parsed = KoonCurrencyService.parsePriceToDouble(newPrice);
      if (parsed > 0) {
        itemStatuses[itemId] = 'success';
        itemUpdatedPrices[itemId] = newPrice;
        final sarPrice = await KoonCurrencyService.convertToSar(newPrice);
        await updateItemPrice(itemId, sarPrice);
      } else {
        itemStatuses[itemId] = 'error';
      }
    } else {
      itemStatuses[itemId] = 'success';
    }
    _nextQueueItem();
  }

  void onRefreshFailed(String itemId) {
    _refreshTimeout?.cancel();
    itemStatuses[itemId] = 'error';
    _nextQueueItem();
  }


  Future<void> _refreshTotalCount() async {
    // Get total count across all cart types
    final lang = Get.locale?.languageCode ?? 'en';
    final allItems = await _cartService.getCart(lang: lang);
    totalCartCount.value = allItems.length;
  }

  Future<AddToCartStatus> addToCart({
    required String cartType,
    String? productId,
    String? title,
    String? price,
    String? imageUrl,
    String? externalUrl,
    String? siteName,
    String? selectionsJson,
    int minQuantity = 1,
    int quantity = 1,
  }) async {
    String? convertedPrice = price;
    if (price != null) {
      convertedPrice = await KoonCurrencyService.convertToSar(price);
    }

    try {
      final result = await _cartService.addToCart(
        cartType: cartType,
        productId: productId,
        title: title,
        price: convertedPrice,
        imageUrl: imageUrl,
        externalUrl: externalUrl,
        siteName: siteName,
        selectionsJson: selectionsJson,
        minQuantity: minQuantity,
        quantity: quantity,
      );
      if (result != null) {
        // Auto-switch the active cart to the one we just added to, so the cart
        // screen shows the correct site's cart (e.g. Alibaba) instead of staying
        // on whatever was manually selected in the dropdown.
        selectedCartType.value = cartType;
        await loadCart();
        return AddToCartStatus.success;
      }
      return AddToCartStatus.error;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return AddToCartStatus.unauthorized;
      }
      return AddToCartStatus.error;
    } catch (_) {
      return AddToCartStatus.error;
    }
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final success = await _cartService.updateCartItem(itemId, quantity: quantity);
    if (success) await loadCart();
  }

  Future<void> updateItemPrice(String itemId, String price) async {
    final success = await _cartService.updateCartItem(itemId, price: price);
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
        final rawPrice = item['price'] ?? item['product']?['price'];
        final price = KoonCurrencyService.parsePriceToDouble(rawPrice);
        final qty = item['quantity'] ?? 1;
        total += price * qty;
      }
    }
    return total;
  }
}
