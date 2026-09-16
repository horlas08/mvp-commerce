import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/webview/webview_screen.dart';

/// Manages active store browsing sessions, keeping each visited store alive
/// in the background across navigation visits (Preserving Browser State).
class StoreBrowserController extends GetxController {
  static StoreBrowserController get to {
    if (!Get.isRegistered<StoreBrowserController>()) {
      return Get.put(StoreBrowserController(), permanent: true);
    }
    return Get.find<StoreBrowserController>();
  }

  final RxBool isStoreOpen = false.obs;
  final RxString activeStoreKey = ''.obs;
  final RxMap<String, Widget> cachedStores = <String, Widget>{}.obs;

  // Track access order for LRU (Least Recently Used) cache eviction
  final List<String> _accessOrder = [];
  static const int maxCachedStores = 5;

  /// Opens the store. If the store was previously opened, reveals it instantly (0ms)
  /// with all scroll position, loaded items, and DOM state preserved.
  void openStore({
    required String name,
    required String url,
    DateTime? clickTime,
  }) {
    final key = name.toLowerCase().trim();
    debugPrint('[StoreBrowserController] openStore called: "$name" ($key) -> $url');

    _accessOrder.remove(key);
    _accessOrder.add(key);

    if (cachedStores.containsKey(key)) {
      debugPrint('[StoreBrowserController] Resuming existing cached WebView for $name (0ms instant)');
      activeStoreKey.value = key;
      isStoreOpen.value = true;
      return;
    }

    // If cache exceeds limit, evict the oldest unviewed store
    if (cachedStores.length >= maxCachedStores && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.firstWhere(
        (k) => k != key,
        orElse: () => _accessOrder.first,
      );
      _accessOrder.remove(oldestKey);
      cachedStores.remove(oldestKey);
      debugPrint('[StoreBrowserController] Evicted oldest store from cache: $oldestKey');
    }

    debugPrint('[StoreBrowserController] Creating new cached WebViewScreen for $name');
    cachedStores[key] = WebViewScreen(
      key: ValueKey('store_$key'),
      initialUrl: url,
      siteName: name,
      clickTime: clickTime,
      onClose: closeStore,
    );
    activeStoreKey.value = key;
    isStoreOpen.value = true;
  }

  /// Closes the visible store overlay and returns to the app shell without destroying state.
  void closeStore() {
    debugPrint('[StoreBrowserController] closeStore: hiding active store overlay');
    isStoreOpen.value = false;
  }

  /// Clears a specific store or all cached stores.
  void clearStore({String? name}) {
    if (name != null) {
      final key = name.toLowerCase().trim();
      _accessOrder.remove(key);
      cachedStores.remove(key);
      if (activeStoreKey.value == key) {
        isStoreOpen.value = false;
        activeStoreKey.value = '';
      }
    } else {
      _accessOrder.clear();
      cachedStores.clear();
      isStoreOpen.value = false;
      activeStoreKey.value = '';
    }
  }
}
