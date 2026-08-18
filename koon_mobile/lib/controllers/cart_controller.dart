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

  final RxString selectedCartType = 'amazon'.obs;
  final RxList<Map<String, dynamic>> cartItems = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt totalCartCount = 0.obs;

  // ── Cart Auto-Update Refresh States & Queue ─────────────────────────────
  final RxList<Map<String, dynamic>> refreshQueue = <Map<String, dynamic>>[].obs;
  final RxMap<String, String> itemStatuses = <String, String>{}.obs;
  final RxMap<String, String> itemErrors = <String, String>{}.obs;
  final RxMap<String, String> itemUpdatedPrices = <String, String>{}.obs;
  final Rxn<Map<String, dynamic>> currentRefreshItem = Rxn<Map<String, dynamic>>();
  Timer? _refreshTimeout;

  final List<Map<String, String>> cartTypes = [
    // {'key': 'internal', 'label_en': 'Internal Cart', 'label_ar': 'السلة الداخلية'},
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

  Future<void> loadCart({bool autoRefresh = true}) async {
    isLoading.value = true;
    final lang = Get.locale?.languageCode ?? 'en';
    cartItems.value = await _cartService.getCart(cartType: selectedCartType.value, lang: lang);
    isLoading.value = false;
    _refreshTotalCount();

    if (autoRefresh && selectedCartType.value != 'internal') {
      startCartRefresh();
    }
  }

  bool isItemFresh(Map<String, dynamic> item) {
    final rawPrice = item['price'] ?? item['product']?['price'];
    final parsedPrice = KoonCurrencyService.parsePriceToDouble(rawPrice);
    // If price is missing or 0 or unknown, it is NOT fresh -> needs refresh
    if (parsedPrice <= 0 || rawPrice == null || rawPrice.toString().toLowerCase().contains('unknown')) {
      return false;
    }

    final now = DateTime.now();

    // Check updated_at
    final updatedAtStr = item['updated_at']?.toString();
    if (updatedAtStr != null && updatedAtStr.isNotEmpty) {
      final updatedAt = DateTime.tryParse(updatedAtStr)?.toLocal();
      if (updatedAt != null) {
        final isToday = updatedAt.year == now.year && updatedAt.month == now.month && updatedAt.day == now.day;
        if (isToday) return true; // Price updated today -> fresh!
      }
    }

    // Check created_at (added to cart today)
    final createdAtStr = item['created_at']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
      if (createdAt != null) {
        final isToday = createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day;
        if (isToday) return true; // Added to cart today -> fresh!
      }
    }

    return false; // Stale or from previous day -> needs refresh
  }

  void startCartRefresh({bool forceAll = false}) {
    _refreshTimeout?.cancel();
    refreshQueue.clear();
    itemStatuses.clear();
    itemErrors.clear();
    itemUpdatedPrices.clear();
    currentRefreshItem.value = null;

    final externalItems = cartItems.where((item) {
      final extUrl = item['external_url']?.toString() ?? '';
      if (extUrl.isEmpty) return false;
      if (forceAll) return true;
      // Only refresh items that were NOT updated today or NOT added today
      return !isItemFresh(item);
    }).toList();

    // For items that ARE fresh, mark them as 'success' immediately
    for (var item in cartItems) {
      final extUrl = item['external_url']?.toString() ?? '';
      if (extUrl.isNotEmpty && isItemFresh(item) && !forceAll) {
        itemStatuses[item['id']] = 'success';
      }
    }

    if (externalItems.isEmpty) {
      Get.log('[CartAutoUpdate] All items are fresh (added or updated today). No refresh needed.');
      return;
    }

    Get.log('[CartAutoUpdate] Found ${externalItems.length} stale items needing refresh in $selectedCartType cart');

    for (var item in externalItems) {
      itemStatuses[item['id']] = 'pending';
    }
    refreshQueue.addAll(externalItems);
    _nextQueueItem();
  }

  void retryItemRefresh(String itemId) {
    final item = cartItems.firstWhereOrNull((i) => i['id'] == itemId);
    if (item == null) return;
    itemStatuses[itemId] = 'pending';
    itemErrors.remove(itemId);
    refreshQueue.add(item);
    if (currentRefreshItem.value == null) {
      _nextQueueItem();
    }
  }

  void _nextQueueItem() {
    _refreshTimeout?.cancel();
    if (refreshQueue.isEmpty) {
      currentRefreshItem.value = null;
      Get.log('[CartAutoUpdate] All items finished refreshing.');
      return;
    }
    final item = refreshQueue.removeAt(0);
    currentRefreshItem.value = item;
    itemStatuses[item['id']] = 'updating';
    itemErrors.remove(item['id']);

    Get.log('[CartAutoUpdate] ⏳ Refreshing item ${item['id']} (${item['title']})...');

    _refreshTimeout = Timer(const Duration(seconds: 18), () {
      if (currentRefreshItem.value?['id'] == item['id']) {
        Get.log('[CartAutoUpdate] ⏱️ Timeout refreshing cart item ${item['id']}');
        onRefreshFailed(item['id'], reason: 'Page load timed out (18s)');
      }
    });
  }

  void onRefreshComplete(String itemId, String? newPrice, {bool outOfStock = false}) async {
    _refreshTimeout?.cancel();
    if (outOfStock) {
      itemStatuses[itemId] = 'out_of_stock';
      itemErrors.remove(itemId);
      Get.log('[CartAutoUpdate] ⚠️ Item $itemId marked as Out of Stock');
      await updateItemPrice(itemId, "Out of Stock");
    } else if (newPrice != null && newPrice.isNotEmpty && !newPrice.toLowerCase().contains('unknown')) {
      final parsed = KoonCurrencyService.parsePriceToDouble(newPrice);
      if (parsed > 0) {
        itemStatuses[itemId] = 'success';
        itemErrors.remove(itemId);
        itemUpdatedPrices[itemId] = newPrice;
        final sarPrice = await KoonCurrencyService.convertToSar(newPrice);
        Get.log('[CartAutoUpdate] ✅ Item $itemId refreshed: original=$newPrice -> SAR=$sarPrice');
        await updateItemPrice(itemId, sarPrice);
      } else {
        itemStatuses[itemId] = 'error';
        itemErrors[itemId] = 'Could not parse price: $newPrice';
        Get.log('[CartAutoUpdate] ❌ Failed parsing price for $itemId: $newPrice');
      }
    } else {
      itemStatuses[itemId] = 'success';
      itemErrors.remove(itemId);
    }
    _nextQueueItem();
  }

  void onRefreshFailed(String itemId, {String? reason}) {
    _refreshTimeout?.cancel();
    itemStatuses[itemId] = 'error';
    itemErrors[itemId] = reason ?? 'Auto-update scrape failed';
    Get.log('[CartAutoUpdate] ❌ Item $itemId refresh failed: $reason');
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
        await loadCart(autoRefresh: true);
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
    final item = cartItems.firstWhereOrNull((i) => i['id'] == itemId);
    final minQty = (item?['min_quantity'] is int)
        ? item!['min_quantity'] as int
        : int.tryParse(item?['min_quantity']?.toString() ?? '1') ?? 1;
    final safeQty = quantity < minQty ? minQty : quantity;

    final index = cartItems.indexWhere((i) => i['id'] == itemId);
    if (index != -1) {
      final updated = Map<String, dynamic>.from(cartItems[index]);
      updated['quantity'] = safeQty;
      cartItems[index] = updated;
      cartItems.refresh();
    }
    await _cartService.updateCartItem(itemId, quantity: safeQty);
  }

  Future<void> updateItemPrice(String itemId, String price) async {
    final index = cartItems.indexWhere((i) => i['id'] == itemId);
    if (index != -1) {
      final updated = Map<String, dynamic>.from(cartItems[index]);
      updated['price'] = price;
      updated['updated_at'] = DateTime.now().toUtc().toIso8601String();
      if (updated['product'] is Map) {
        final prod = Map<String, dynamic>.from(updated['product']);
        prod['price'] = price;
        updated['product'] = prod;
      }
      cartItems[index] = updated;
      cartItems.refresh();
    }
    await _cartService.updateCartItem(itemId, price: price);
  }

  Future<void> toggleSelection(String itemId, bool isSelected) async {
    final index = cartItems.indexWhere((i) => i['id'] == itemId);
    if (index != -1) {
      final updated = Map<String, dynamic>.from(cartItems[index]);
      updated['is_selected'] = isSelected;
      cartItems[index] = updated;
      cartItems.refresh();
    }
    await _cartService.updateCartItem(itemId, isSelected: isSelected);
  }

  Future<void> removeItem(String itemId) async {
    final success = await _cartService.removeFromCart(itemId);
    if (success) await loadCart(autoRefresh: false);
  }

  Future<void> clearCurrentCart() async {
    final success = await _cartService.clearCart(cartType: selectedCartType.value);
    if (success) await loadCart(autoRefresh: false);
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
