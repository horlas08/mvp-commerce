import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ScraperHelper {
  static String? _cachedWorkerJs;

  /// Preload the worker script template into memory (optional, called at startup).
  static Future<void> preload() async {
    try {
      _cachedWorkerJs ??= await rootBundle.loadString('assets/worker.js');
    } catch (_) {}
  }

  /// Builds the scraper script by loading assets/worker.js and replacing placeholders.
  static Future<String> buildScraperScript(Map<String, dynamic> config) async {
    _cachedWorkerJs ??= await rootBundle.loadString('assets/worker.js');
    return applyConfig(_cachedWorkerJs!, config);
  }

  /// Synchronous fallback if assets/worker.js was already loaded into memory.
  static String? buildScraperScriptSync(Map<String, dynamic> config) {
    if (_cachedWorkerJs == null) return null;
    return applyConfig(_cachedWorkerJs!, config);
  }

  /// Injects configuration into the given raw JavaScript template.
  static String applyConfig(String template, Map<String, dynamic> config) {
    final hideSelectors = List<String>.from(config['hide_selectors'] ?? []);
    final titleSelector = config['title_selector'] ?? '';
    final priceSelectors = List<String>.from(config['price_selectors'] ?? []);
    final imageSelectorsJson = jsonEncode(config['image_selectors'] ?? []);
    final siteName = config['name'] ?? '';

    // Add footer and call-app fallbacks for AliExpress/Alibaba/Shein etc
    final nameLower = siteName.toLowerCase();
    if (nameLower.contains('aliexpress') || nameLower.contains('alibaba') || nameLower.contains('shein')) {
      final fallbacks = [
        '.bottom-bar',
        "[class*='bottom-bar']",
        "[class*='bottomBar']",
        "[id*='bottom-bar']",
        "[id*='bottomBar']",
        '.footer-bar',
        "[class*='footer-bar']",
        "[class*='footerBar']",
        "[id*='footer-bar']",
        "[id*='footerBar']",
        '#action-bar',
        '.action-bar',
        "[class*='action-bar']",
        "[class*='actionBar']",
      ];
      for (final f in fallbacks) {
        if (!hideSelectors.contains(f)) {
          hideSelectors.add(f);
        }
      }
    }
    if (nameLower.contains('alibaba')) {
      final alibabaCallAppFallbacks = [
        '#call-app-dialog',
        '.call-app-dialog',
        '.call-app-dialog-main',
        '#call-app-button',
        '.call-app-button',
        '.call-app-dialog-mask',
        '.call-app-btn-overlay',
        '.call-app-page-overlay',
        "[class*='call-app']",
        "[id*='call-app']",
        "[class*='callApp']",
        "[id*='callApp']",
        '.m-app-banner',
        '.app-banner',
        '.smart-banner',
      ];
      for (final f in alibabaCallAppFallbacks) {
        if (!hideSelectors.contains(f)) {
          hideSelectors.add(f);
        }
      }
      final alibabaPriceFallbacks = [
        "[data-testid='range-prices'] span",
        "[data-testid='range-prices']",
        "[data-testid='ladder-prices'] span",
        "[data-testid='ladder-prices']",
        "[data-testid*='price'] span",
        "[data-testid*='price']",
        ".product-price span",
        ".product-price",
        "[class*='product-price']",
        ".module-pdp-price .price",
      ];
      for (final p in alibabaPriceFallbacks) {
        if (!priceSelectors.contains(p)) {
          priceSelectors.add(p);
        }
      }
    }
    final hideSelectorsJson = jsonEncode(hideSelectors);
    final priceSelectorsJson = jsonEncode(priceSelectors);

    String js = template;
    js = js.replaceAll('__HIDE_SELECTORS_JSON__', hideSelectorsJson);
    js = js.replaceAll('__TITLE_SELECTOR__', titleSelector);
    js = js.replaceAll('__PRICE_SELECTORS_JSON__', priceSelectorsJson);
    js = js.replaceAll('__IMAGE_SELECTORS_JSON__', imageSelectorsJson);
    js = js.replaceAll('__SITE_NAME__', siteName);
    return js;
  }
}
