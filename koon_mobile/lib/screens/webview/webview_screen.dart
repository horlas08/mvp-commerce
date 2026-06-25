import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/config_controller.dart';
import '../../services/api_service.dart';
import '../../services/wishlist_service.dart';
import '../../app/constants/api_constants.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String siteName;

  const WebViewScreen({
    super.key,
    required this.initialUrl,
    required this.siteName,
  });

  // ── Currency Cookie Setter (force SAR display on the website itself) ──────
  static Future<void> setupCurrencyCookies(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final cookieManager = CookieManager.instance();
      final expiresDate = DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch;

      if (host.contains('alibaba.com')) {
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "sc_currency",
          value: "SAR",
          domain: ".alibaba.com",
          expiresDate: expiresDate,
          isSecure: true,
        );
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "sc_country",
          value: "SA",
          domain: ".alibaba.com",
          expiresDate: expiresDate,
          isSecure: true,
        );
      } else if (host.contains('aliexpress.com')) {
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "aep_usuc_f",
          value: "site=glo&c_tp=SAR&region=SA&b_locale=en_US",
          domain: ".aliexpress.com",
          expiresDate: expiresDate,
          isSecure: true,
        );
      }
    } catch (e) {
      debugPrint('[webview] Cookie setup failed: $e');
    }
  }

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;

  bool _isLoading = false;
  double _progress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  Map<String, dynamic>? _currentConfig;
  Map<String, dynamic>? _currentProduct;
  String? _loadError;

  // ── HTML source dumping (dev tool) ────────────────────────────────────────
  // Saves the live page HTML to <appExternalStorage>/<site>_source.html so we
  // can inspect the DOM and add hide-selectors for popups, login modals, etc.
  // Disabled by default: auto-dumping serialized the entire DOM (~700KB on
  // Alibaba) over the JS bridge on every load, which stalled the page. Use the
  // "Dump now" button (code icon in the app bar) when you need a snapshot, or
  // toggle auto-dump back on there.
  bool _dumpEnabled = false;
  String? _lastDumpPath;
  int _lastDumpBytes = 0;
  DateTime? _lastDumpAt;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;

    // Set cookies to force SAR currency display on the website itself
    WebViewScreen.setupCurrencyCookies(widget.initialUrl);

    // Set config synchronously from prefetch if available
    final configController = Get.find<ConfigController>();
    final config = configController.getConfigForUrl(widget.initialUrl);
    if (config != null) {
      _currentConfig = config;
    } else {
      _fetchConfigFromApi(widget.initialUrl);
    }
  }

  // ── Backend config loader (per-site selectors/JS) ─────────────────────────
  void _loadConfigForUrl(String url) {
    final configController = Get.find<ConfigController>();
    final config = configController.getConfigForUrl(url);
    if (config != null) {
      if (mounted) {
        setState(() => _currentConfig = config);
      } else {
        _currentConfig = config;
      }
      _applyHidingAndScraping();
    } else {
      _fetchConfigFromApi(url);
    }
  }

  Future<void> _fetchConfigFromApi(String url) async {
    try {
      final response = await ApiService().dio.get(
        ApiConstants.scraperConfig,
        queryParameters: {'url': url},
      );
      if (mounted && response.statusCode == 200) {
        setState(() => _currentConfig = response.data);
        _applyHidingAndScraping();
      }
    } catch (_) {}
  }

  // Throttle so the heavy combined-JS isn't re-injected on every progress tick.
  DateTime? _lastInjectAt;

  // ── Inject CSS + JS to hide native cart/login UI & scrape product ────────
  void _applyHidingAndScraping({bool force = false}) async {
    if (_webViewController == null || _currentConfig == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastInjectAt != null &&
        now.difference(_lastInjectAt!).inMilliseconds < 1500) {
      return;
    }
    _lastInjectAt = now;

    final hideSelectors = List<String>.from(_currentConfig!['hide_selectors']);
    final titleSelector = _currentConfig!['title_selector'];
    final priceSelectorsJson = jsonEncode(_currentConfig!['price_selectors']);
    final imageSelectorsJson = jsonEncode(_currentConfig!['image_selectors']);
    final siteName = _currentConfig!['name'];
    final hideSelectorsJson = jsonEncode(hideSelectors);

    final combinedJs = """
      (function() {
        'use strict';
        const SELECTORS = $hideSelectorsJson;
        function hideElements() {
          for (const sel of SELECTORS) {
            try {
              const nodes = document.querySelectorAll(sel);
              nodes.forEach(node => {
                node.setAttribute('style',
                  'display:none!important;visibility:hidden!important;' +
                  'pointer-events:none!important;opacity:0!important;' +
                  'width:0!important;height:0!important;max-height:0!important;' +
                  'overflow:hidden!important;');
              });
            } catch(e) {}
          }
        }
        // Throttle the observer: Alibaba is a heavy SPA that mutates the DOM
        // constantly, so running hideElements() on every mutation pegs the CPU
        // and makes scrolling/loading janky. Coalesce bursts into one run.
        if (!window._hideObserver) {
          window._hidePending = false;
          window._hideObserver = new MutationObserver(() => {
            if (window._hidePending) return;
            window._hidePending = true;
            setTimeout(() => { window._hidePending = false; hideElements(); }, 350);
          });
          window._hideObserver.observe(document.body || document.documentElement, { childList: true, subtree: true, attributes: false });
        }
        if (!window._hideIntervalId) {
          hideElements();
          window._hideIntervalId = setInterval(hideElements, 1200);
        } else {
          hideElements();
        }
        // Parse schema.org Product JSON-LD (most reliable source for title,
        // price & image — works even when the visible DOM uses minified /
        // localized classes like Alibaba's "id-text-[...]" tailwind classes).
        function getJsonLdProduct() {
          try {
            const scripts = document.querySelectorAll('script[type="application/ld+json"]');
            for (const s of scripts) {
              let data;
              try { data = JSON.parse(s.textContent); } catch(e) { continue; }
              const items = Array.isArray(data) ? data : (data['@graph'] ? data['@graph'] : [data]);
              for (const item of items) {
                if (!item || !item['@type']) continue;
                const types = Array.isArray(item['@type']) ? item['@type'] : [item['@type']];
                if (types.indexOf('Product') === -1) continue;
                let offers = item.offers;
                if (Array.isArray(offers)) offers = offers[0];
                let rawPrice = '';
                let currency = '';
                if (offers) {
                  currency = offers.priceCurrency || '';
                  if (offers.lowPrice && offers.highPrice && offers.lowPrice !== offers.highPrice) {
                    rawPrice = offers.lowPrice + ' - ' + offers.highPrice;
                  } else {
                    rawPrice = offers.price || offers.lowPrice ||
                      (offers.priceSpecification && offers.priceSpecification.price) || '';
                  }
                }
                let priceStr = '';
                if (rawPrice) {
                  const symbols = { USD: '\$', EUR: '€', GBP: '£', CNY: '¥', JPY: '¥', SAR: 'SAR ', AED: 'AED ', NGN: '₦' };
                  const sym = symbols[currency];
                  priceStr = sym ? (sym + rawPrice) : (currency ? (currency + ' ' + rawPrice) : ('' + rawPrice));
                }
                let image = '';
                if (item.image) { image = Array.isArray(item.image) ? item.image[0] : item.image; }
                let name = item.name || '';
                if (name && typeof name === 'object') { name = name['@value'] || ''; }
                return { name: ('' + name).trim(), price: priceStr, image: ('' + image).trim() };
              }
            }
          } catch(e) {}
          return null;
        }
        function isPlaceholderValue(v) {
          if (!v) return true;
          return /^(select|choose|please select|pick|请选择|请选择|اختر|حدد)/i.test(('' + v).trim());
        }
        function readBorderBoxOption(box) {
          const img = box.querySelector('img[alt]');
          if (img && img.alt && img.alt.trim()) return img.alt.trim();
          const span = box.querySelector('span');
          return span ? span.textContent.trim() : '';
        }
        function isBorderBoxSelected(box) {
          const cls = box.className || '';
          return /\\bselected\\b/.test(cls) && !/\\bunselected\\b/.test(cls);
        }
        function normalizeAttrName(name) {
          return ('' + name).trim().replace(/\\(\\d+\\)\$/, '').replace(/[:：]\\s*\$/, '').trim();
        }
        function isVisibleEl(el) {
          if (!el || !el.getBoundingClientRect) return false;
          const rect = el.getBoundingClientRect();
          if (rect.width <= 0 || rect.height <= 0) return false;
          const style = window.getComputedStyle(el);
          return style.display !== 'none' && style.visibility !== 'hidden' && parseFloat(style.opacity || '1') > 0;
        }
        function upsertSelection(selections, entry) {
          const key = normalizeAttrName(entry.name);
          if (!key) return null;
          let sel = selections.find(s => normalizeAttrName(s.name) === key);
          if (!sel) {
            sel = { name: key, value: entry.value || '', options: [] };
            selections.push(sel);
          }
          (entry.options || []).forEach(o => {
            o = ('' + o).trim();
            if (o && sel.options.indexOf(o) === -1) sel.options.push(o);
          });
          if (entry.value && !isPlaceholderValue(entry.value)) sel.value = entry.value;
          else if (!sel.value && sel.options.length === 1) sel.value = sel.options[0];
          return sel;
        }
        function finalizeSelections(selections) {
          const merged = [];
          selections.forEach(entry => {
            upsertSelection(merged, entry);
          });
          return merged.filter(s => {
            if (s.options.length > 0) return true;
            return s.value && !isPlaceholderValue(s.value);
          }).map(s => {
            if (!s.value && s.options.length === 1) s.value = s.options[0];
            return s;
          });
        }
        function parseSkuListBlock(list, selections) {
          const titleEl = list.querySelector('[data-testid="sku-list-title"] span, [data-testid="sku-list-title"]');
          let name = titleEl ? normalizeAttrName(titleEl.textContent) : '';
          if (!name) return;
          const options = [];
          let value = '';
          list.querySelectorAll('[data-testid="double-bordered-box"]').forEach(box => {
            const opt = readBorderBoxOption(box);
            if (opt && options.indexOf(opt) === -1) options.push(opt);
            if (isBorderBoxSelected(box) && opt) value = opt;
          });
          upsertSelection(selections, { name: name, value: value, options: options });
        }
        function extractSkuMeta() {
          const selections = [];
          let hasVariants = false;
          let requiresSelection = false;
          let minQuantity = 1;
          let selectedQuantity = 0;
          const skuRoots = [
            document.querySelector('[data-testid="sku-summary"]'),
            document.querySelector('[data-module-name="module_sku"]'),
          ].filter(Boolean);
          skuRoots.forEach(root => {
            hasVariants = true;
            root.querySelectorAll('[data-testid="sku-summary-attr-floor"]').forEach(floor => {
              let name = floor.getAttribute('data-attr-name') || '';
              if (!name) {
                const h = floor.querySelector('h2,h3');
                name = h ? h.textContent.trim().replace(/\\(\\d+\\)\$/, '').trim() : '';
              }
              const options = [];
              floor.querySelectorAll('[data-testid="sku-summary-value-name"]').forEach(el => {
                const v = el.textContent.trim();
                if (v && options.indexOf(v) === -1) options.push(v);
              });
              let value = '';
              floor.querySelectorAll('[data-testid="sku-summary-value"]').forEach(el => {
                const cls = (el.className || '') + ' ' + (el.getAttribute('aria-selected') || '');
                const selected = /selected|active|border|ring/i.test(cls);
                const v = el.querySelector('[data-testid="sku-summary-value-name"]');
                if (selected && v) value = v.textContent.trim();
              });
              if (!value && options.length === 1) value = options[0];
              const items = floor.querySelectorAll('[data-testid="sku-summary-value"]');
              if (!value && items.length === 1) {
                const v = items[0].querySelector('[data-testid="sku-summary-value-name"]');
                if (v) value = v.textContent.trim();
              }
              if (!value && options.length > 1) requiresSelection = true;
              if (isPlaceholderValue(value)) requiresSelection = true;
              if (name) upsertSelection(selections, { name: name, value: value, options: options });
            });
            if (!root.querySelector('[data-testid="sku-summary"]')) {
              root.querySelectorAll('[data-testid="sku-list"]').forEach(list => parseSkuListBlock(list, selections));
            }
          });
          document.querySelectorAll('[data-testid="sku-panel-sku-group"]').forEach(group => {
            if (!isVisibleEl(group)) return;
            hasVariants = true;
            let name = group.getAttribute('data-sku-group-name') || '';
            let value = '';
            const h4 = group.querySelector('h4 span, h4');
            if (h4) {
              const text = h4.textContent.trim();
              if (!name && text.indexOf(':') !== -1) {
                const parts = text.split(':');
                name = parts[0].trim();
                value = parts.slice(1).join(':').trim();
              } else if (!name) {
                name = text;
              }
            }
            const options = [];
            group.querySelectorAll('[data-testid="double-bordered-box"]').forEach(box => {
              const opt = readBorderBoxOption(box);
              if (opt && options.indexOf(opt) === -1) options.push(opt);
              if (isBorderBoxSelected(box) && opt) value = opt;
            });
            if (name) upsertSelection(selections, { name: name, value: value, options: options });
          });
          document.querySelectorAll('[data-testid="sku-panel-sku"]').forEach(panel => {
            if (!isVisibleEl(panel)) return;
            hasVariants = true;
            panel.querySelectorAll('[data-testid="sku-summary-attr-floor"], [data-testid*="attr-floor"]').forEach(floor => {
              let name = floor.getAttribute('data-attr-name') || '';
              if (!name) {
                const h = floor.querySelector('h2,h3');
                name = h ? normalizeAttrName(h.textContent) : '';
              } else {
                name = normalizeAttrName(name);
              }
              if (!name) return;
              const options = [];
              let value = '';
              floor.querySelectorAll('[data-testid="sku-summary-value-name"], [data-testid*="value-name"]').forEach(el => {
                const v = el.textContent.trim();
                if (v && options.indexOf(v) === -1) options.push(v);
              });
              floor.querySelectorAll('[data-testid="sku-summary-value"]').forEach(el => {
                const cls = (el.className || '') + ' ' + (el.getAttribute('aria-selected') || '');
                const selected = /selected|active|border|ring/i.test(cls);
                const v = el.querySelector('[data-testid="sku-summary-value-name"]');
                if (selected && v) value = v.textContent.trim();
              });
              if (!value && options.length === 1) value = options[0];
              upsertSelection(selections, { name: name, value: value, options: options });
            });
            panel.querySelectorAll('[data-testid="sku-list"]').forEach(list => parseSkuListBlock(list, selections));
          });
          document.querySelectorAll('input[aria-label="Quantity"]').forEach(inp => {
            const q = parseInt(('' + (inp.value || '0')).replace(/[^\\d]/g, ''), 10) || 0;
            selectedQuantity += q;
          });
          const ladder = document.querySelector('[data-testid="ladder-prices"]');
          if (ladder) {
            const tier = ladder.querySelector('[class*="text-nowrap"]');
            const tierText = tier ? tier.textContent.trim() : '';
            const m = tierText.match(/(\\d+)/);
            if (m) minQuantity = Math.max(minQuantity, parseInt(m[1], 10) || 1);
          }
          const ladderPrice = document.querySelector('[data-testid="ladder-price"]');
          if (ladderPrice) {
            const firstTier = ladderPrice.querySelector('.price-item');
            if (firstTier) {
              const m = firstTier.textContent.match(/(\\d+)/);
              if (m) minQuantity = Math.max(minQuantity, parseInt(m[1], 10) || 1);
            }
          }
          const skuScope = document.querySelector('[data-module-name="module_sku"], [data-testid="sku-panel-sku"], [data-testid="product-price"]');
          if (skuScope) {
            const moqMatch = skuScope.textContent.match(/MOQ[:\\s]+(\\d+)/i);
            if (moqMatch) minQuantity = Math.max(minQuantity, parseInt(moqMatch[1], 10) || 1);
          }
          document.querySelectorAll('#twister .a-row, [id^="variation_"]').forEach(row => {
            const label = row.querySelector('label, .a-form-label');
            const selected = row.querySelector('.selection, .a-dropdown-prompt, .twisterTextDiv');
            const name = label ? label.textContent.trim().replace(':', '') : '';
            const value = selected ? selected.textContent.trim() : '';
            if (name) {
              hasVariants = true;
              if (!value || isPlaceholderValue(value)) requiresSelection = true;
              selections.push({ name: name, value: value, options: value ? [value] : [] });
            }
          });
          const finalSelections = finalizeSelections(selections);
          if (finalSelections.length) hasVariants = true;
          finalSelections.forEach(s => {
            if (!s.value && s.options.length > 1) requiresSelection = true;
            if (isPlaceholderValue(s.value)) requiresSelection = true;
          });
          const selectionSummary = finalSelections.filter(s => s.value).map(s => s.name + ': ' + s.value).join(' | ');
          return {
            has_variants: hasVariants,
            requires_selection: requiresSelection,
            selections: finalSelections,
            min_quantity: minQuantity,
            selected_quantity: selectedQuantity,
            selection_summary: selectionSummary,
          };
        }
        function extractProduct() {
          try {
            const ld = getJsonLdProduct();
            const sku = extractSkuMeta();
            let title = '';
            const titleElem = document.querySelector("$titleSelector");
            if (titleElem) title = titleElem.textContent.trim();
            if (!title && ld && ld.name) title = ld.name;
            if (!title) return null;
            const priceSelectors = $priceSelectorsJson;
            let price = "Unknown Price";
            for (const selector of priceSelectors) {
              const elem = document.querySelector(selector);
              if (elem) { const text = elem.textContent.trim(); if (text) { price = text; break; } }
            }
            if ((price === "Unknown Price" || !price) && ld && ld.price) { price = ld.price; }
            const imageSelectors = $imageSelectorsJson;
            let imageUrl = "";
            for (const selector of imageSelectors) {
              const elem = document.querySelector(selector);
              if (elem) {
                if (elem.src && elem.src.startsWith('http')) { imageUrl = elem.src; }
                else if (elem.getAttribute("data-a-dynamic-image")) {
                  try { const dyn = JSON.parse(elem.getAttribute("data-a-dynamic-image")); imageUrl = Object.keys(dyn)[0]; } catch(e2) {}
                }
                if (imageUrl) break;
              }
            }
            if (!imageUrl && ld && ld.image) { imageUrl = ld.image; }
            return Object.assign({
              title: title,
              price: price,
              image_url: imageUrl,
              url: window.location.href,
              site: "$siteName",
            }, sku);
          } catch (e) { return null; }
        }
        window.__koonExtractProduct = extractProduct;
        window.__koonOpenSkuPicker = function() {
          const action = document.querySelector('[data-testid="sku-action"]');
          if (action) { action.click(); return true; }
          const layout = document.querySelector('[data-module-name="module_sku"] [data-testid="sku-layout"], [data-testid="sku-summary"]');
          if (layout) { layout.click(); return true; }
          const panel = document.querySelector('[data-testid="sku-panel-sku"]');
          if (panel) { panel.scrollIntoView({ behavior: 'smooth', block: 'center' }); return true; }
          return false;
        };
        if (!window._scraperIntervalId) {
          window._scraperIntervalId = setInterval(() => {
            const product = extractProduct();
            if (product) { window.flutter_inappwebview.callHandler('onProductDetected', product); }
          }, 1000);
        }
      })();
    """;

    await _webViewController!.evaluateJavascript(source: combinedJs);
  }

  // ── Cart helpers ─────────────────────────────────────────────────────────
  String _cartTypeForSite() {
    final name = widget.siteName.toLowerCase().replaceAll(' ', '');
    if (name.contains('amazon')) return 'amazon';
    if (name.contains('aliexpress')) return 'aliexpress';
    if (name.contains('alibaba')) return 'alibaba';
    if (name.contains('shein')) return 'shein';
    return 'internal';
  }

  Future<Map<String, dynamic>?> _fetchProductFromPage() async {
    if (_webViewController == null) return _currentProduct;
    try {
      final raw = await _webViewController!.evaluateJavascript(
        source: 'window.__koonExtractProduct ? window.__koonExtractProduct() : null',
      );
      if (raw == null) return _currentProduct;
      final data = Map<String, dynamic>.from(raw as Map);
      if (mounted) setState(() => _currentProduct = data);
      return data;
    } catch (_) {
      return _currentProduct;
    }
  }

  Future<void> _openNativeSkuPicker() async {
    await _webViewController?.evaluateJavascript(source: 'window.__koonOpenSkuPicker && window.__koonOpenSkuPicker()');
  }

  String _buildExternalTitle(Map<String, dynamic> product, Map<String, String> chosenSelections) {
    final base = (product['title'] ?? '').toString();
    final parts = chosenSelections.entries
        .where((e) => e.value.trim().isNotEmpty)
        .map((e) => e.value.trim())
        .toList();
    if (parts.isEmpty) {
      final summary = (product['selection_summary'] ?? '').toString().trim();
      if (summary.isNotEmpty) return '$base ($summary)';
      return base;
    }
    return '$base (${parts.join(', ')})';
  }

  Future<void> _handleProductAction(String action) async {
    final product = await _fetchProductFromPage();
    if (product == null) return;

    final authController = Get.find<AuthController>();
    if (!authController.isLoggedIn.value) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (result != true) return;
    }

    final requiresSelection = product['requires_selection'] == true;
    final selections = _parseSelections(product['selections']);

    Map<String, String>? chosen;
    final minQty = (product['min_quantity'] is num) ? (product['min_quantity'] as num).toInt() : 1;
    final pageQty = (product['selected_quantity'] is num) ? (product['selected_quantity'] as num).toInt() : 0;
    int quantity = pageQty > 0 ? pageQty : minQty;

    if (requiresSelection ||
        quantity > 1 ||
        selections.any((s) {
          final opts = s['options'];
          return opts is List && opts.length > 1;
        })) {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ProductSelectionSheet(
          product: product,
          selections: selections,
          initialQuantity: quantity,
          requiresSelection: requiresSelection,
          action: action,
          onOpenNativePicker: _openNativeSkuPicker,
        ),
      );
      if (result == null) return;
      chosen = Map<String, String>.from(result['selections'] as Map? ?? {});
      quantity = (result['quantity'] as num?)?.toInt() ?? quantity;
    }

    final finalTitle = _buildExternalTitle(product, chosen ?? _selectionsToMap(selections));
    final cartType = _cartTypeForSite();

    if (action == 'cart') {
      final cartController = Get.find<CartController>();
      final success = await cartController.addToCart(
        cartType: cartType,
        title: finalTitle,
        price: product['price']?.toString(),
        imageUrl: product['image_url']?.toString(),
        externalUrl: product['url']?.toString(),
        siteName: product['site']?.toString() ?? widget.siteName,
        quantity: quantity,
      );
      _showActionSnack(success, 'added_to_cart'.tr());
    } else {
      final wishlistService = WishlistService();
      final res = await wishlistService.addToWishlist(
        externalUrl: product['url']?.toString(),
        title: finalTitle,
        price: product['price']?.toString(),
        imageUrl: product['image_url']?.toString(),
        source: cartType,
      );
      _showActionSnack(res != null, 'added_to_wishlist'.tr());
    }
  }

  List<Map<String, dynamic>> _parseSelections(dynamic raw) {
    if (raw is! List) return [];
    return _dedupeSelections(raw.map((e) => Map<String, dynamic>.from(e as Map)).toList());
  }

  static String _normAttrName(String name) {
    return name.trim().replaceAll(RegExp(r'\(\d+\)$'), '').replaceAll(RegExp(r'[:：]\s*$'), '');
  }

  static List<Map<String, dynamic>> _dedupeSelections(List<Map<String, dynamic>> raw) {
    final merged = <String, Map<String, dynamic>>{};
    for (final s in raw) {
      final name = _normAttrName((s['name'] ?? '').toString());
      if (name.isEmpty) continue;
      final existing = merged[name];
      if (existing == null) {
        merged[name] = {
          'name': name,
          'value': (s['value'] ?? '').toString(),
          'options': <String>[],
        };
      }
      final target = merged[name]!;
      final opts = target['options'] as List<String>;
      final rawOpts = s['options'];
      if (rawOpts is List) {
        for (final o in rawOpts) {
          final v = o.toString().trim();
          if (v.isNotEmpty && !opts.contains(v)) opts.add(v);
        }
      }
      final value = (s['value'] ?? '').toString().trim();
      if (value.isNotEmpty) target['value'] = value;
    }
    return merged.values.where((s) {
      final opts = s['options'] as List<String>;
      final value = (s['value'] ?? '').toString().trim();
      return opts.isNotEmpty || value.isNotEmpty;
    }).map((s) {
      final opts = s['options'] as List<String>;
      if ((s['value'] ?? '').toString().isEmpty && opts.length == 1) {
        s['value'] = opts.first;
      }
      return s;
    }).toList();
  }

  Map<String, String> _selectionsToMap(List<Map<String, dynamic>> selections) {
    final out = <String, String>{};
    for (final s in selections) {
      final name = (s['name'] ?? '').toString();
      final value = (s['value'] ?? '').toString();
      if (name.isNotEmpty && value.isNotEmpty) out[name] = value;
    }
    return out;
  }

  void _showActionSnack(bool success, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Text(success ? message : 'error_occurred'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onAddToCart() => _handleProductAction('cart');

  Future<void> _onAddToWishlist() => _handleProductAction('wishlist');

  // ── Navigation helpers ───────────────────────────────────────────────────
  Future<void> _refreshNavButtons() async {
    if (_webViewController == null) return;
    final back = await _webViewController!.canGoBack();
    final forward = await _webViewController!.canGoForward();
    if (mounted) setState(() { _canGoBack = back; _canGoForward = forward; });
  }

  void _navigateToUrl(String input) {
    var target = input.trim();
    if (target.isEmpty) return;
    final looksLikeUrl = target.contains('.') && !target.contains(' ');
    if (!looksLikeUrl) {
      target = 'https://www.google.com/search?q=${Uri.encodeComponent(target)}';
    } else if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = 'https://$target';
    }
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
  }

  Future<void> _shareCurrentUrl() async {
    final url = _currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.link, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('link_copied'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openAppCart() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen(showBackButton: true)));
  }

  // ── HTML dump helpers ────────────────────────────────────────────────────
  String _dumpFileSlug() {
    final raw = widget.siteName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final cleaned = raw.replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'webview' : cleaned;
  }

  Future<void> _dumpHtml() async {
    if (!_dumpEnabled || _webViewController == null) return;
    try {
      // Pull the full DOM (including <html>/<head>/<body>) as a JSON-safe string.
      final raw = await _webViewController!
          .evaluateJavascript(source: "document.documentElement.outerHTML");
      if (raw == null) return;
      final html = raw is String ? raw : raw.toString();

      Directory? dir;
      if (Platform.isAndroid) {
        // App-scoped external dir: /storage/emulated/0/Android/data/<pkg>/files/
        // Pullable via: adb pull <path> .   (no root, no extra permissions needed)
        dir = await getExternalStorageDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final header =
          '<!-- Dumped ${DateTime.now().toIso8601String()} from $_currentUrl -->\n';
      final file = File('${dir.path}/${_dumpFileSlug()}_source.html');
      await file.writeAsString(header + html, flush: true);

      if (!mounted) return;
      final length = _safeFileLength(file);
      setState(() {
        _lastDumpPath = file.path;
        _lastDumpBytes = length;
        _lastDumpAt = DateTime.now();
      });
      debugPrint('[webview] dumped $length bytes -> ${file.path}');
    } catch (e) {
      debugPrint('[webview] dump failed: $e');
    }
  }

  int _safeFileLength(File f) {
    try {
      return f.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  String _humanSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _showDumpInfo() async {
    final path = _lastDumpPath;
    final size = _lastDumpBytes;
    final when = _lastDumpAt;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.code, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('HTML source dump'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Auto-dump'),
                const Spacer(),
                Switch.adaptive(
                  value: _dumpEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _dumpEnabled = v);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const Divider(),
            if (path == null)
              const Text('No dump yet. Reload the page to capture the current DOM.')
            else ...[
              const Text('Path:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(path, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              const SizedBox(height: 8),
              Text('Size: ${_humanSize(size)}', style: const TextStyle(fontSize: 12)),
              if (when != null)
                Text('Last update: ${when.toLocal().toString().split('.').first}',
                    style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pull to your PC:\nadb pull "<path>" .\n\nReplace <path> with the path above.',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (path != null)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy path'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Path copied to clipboard')),
                );
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _dumpHtml();
            },
            child: const Text('Dump now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── "Search by link" bottom sheet ────────────────────────────────────────
  Future<void> _openLinkSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LinkSheet(initialUrl: _currentUrl),
    );
    if (result != null && result.isNotEmpty) _navigateToUrl(result);
  }


  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_webViewController != null && await _webViewController!.canGoBack()) {
          _webViewController!.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildWebView(),
            if (_loadError != null) _buildLoadErrorOverlay(),
            if (_currentProduct != null) _buildProductBar(),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLoadingBar(),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: AppColors.error),
        tooltip: 'close'.tr(),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.siteName,
        style: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      actions: [
        _appBarIcon(icon: Icons.code, onTap: _showDumpInfo, tooltip: 'HTML source dump'),
        _appBarIcon(icon: Icons.share_outlined, onTap: _shareCurrentUrl, tooltip: 'share'.tr()),
        _appBarIcon(icon: Icons.travel_explore, onTap: _openLinkSheet, tooltip: 'search_by_link'.tr()),
        _buildCartIconWithBadge(),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap, required String tooltip}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartIconWithBadge() {
    final cartController = Get.find<CartController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Obx(() {
        final count = cartController.totalCartCount.value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _openAppCart,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shopping_basket_outlined, size: 18, color: AppColors.primary),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surface, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        transparentBackground: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        supportZoom: true,
        // Alibaba/AliExpress open product pages via target="_blank" (new
        // window). Without these, those clicks are silently dropped and the
        // page never navigates. We catch the new-window request in
        // onCreateWindow and load it in this same webview instead.
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
        // Block the scripts that auto-evoke the native app and render the
        // "open in app" popup. Alibaba uses @alife/sc-callapp ("换端"/switch-
        // to-app) which fires enalibaba://...&ck=wap_auto_evoke. Killing the
        // script removes BOTH the popup and the redirect attempt at the root.
        contentBlockers: [
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*sc-callapp.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*callapp.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*wakeup.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
        ],
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'onProductDetected',
          callback: (args) {
            if (args.isNotEmpty) {
              final data = Map<String, dynamic>.from(args[0]);
              if (mounted &&
                  (_currentProduct == null ||
                      _currentProduct!['title'] != data['title'] ||
                      _currentProduct!['price'] != data['price'] ||
                      _currentProduct!['selection_summary'] != data['selection_summary'])) {
                setState(() => _currentProduct = data);
              }
            }
          },
        );
      },
      // Some sites (Alibaba, AliExpress, Amazon) open product links in a new
      // window via target="_blank" or window.open(). Capture that here and
      // load the URL in the current webview so the navigation actually happens.
      onCreateWindow: (controller, createWindowAction) async {
        final reqUrl = createWindowAction.request.url;
        final scheme = reqUrl?.scheme.toLowerCase();
        if (reqUrl != null && (scheme == 'http' || scheme == 'https')) {
          await controller.loadUrl(urlRequest: URLRequest(url: reqUrl));
        } else if (reqUrl != null) {
          debugPrint('[webview] blocked new-window app redirect: $reqUrl');
        }
        // We handled it; don't let the platform create a detached window.
        return false;
      },
      // useShouldOverrideUrlLoading is enabled. We allow normal web
      // navigations (http/https) but BLOCK app deep-links. Alibaba's mobile
      // web auto-evokes the native app via a custom scheme, e.g.
      //   enalibaba://sc-home?...&ck=wap_auto_evoke
      // which the webview can't load -> ERR_UNKNOWN_URL_SCHEME blank page.
      // Others use intent://, alibaba://, aplus://, market://, android-app://,
      // itms-apps://. Cancelling all non-web schemes keeps the user in-app.
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url;
        if (uri == null) return NavigationActionPolicy.ALLOW;
        final scheme = uri.scheme.toLowerCase();
        const allowedSchemes = {'http', 'https', 'about', 'data', 'blank'};
        if (!allowedSchemes.contains(scheme)) {
          debugPrint('[webview] blocked app redirect: $uri');
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onLoadStart: (_, url) {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _loadError = null;
            _currentProduct = null;
            _lastInjectAt = null;
            if (url != null) _currentUrl = url.toString();
          });
        }
        if (url != null) {
          final urlStr = url.toString();

          // Force currency cookies to display prices in SAR on the website itself
          WebViewScreen.setupCurrencyCookies(urlStr);

          final currentDomain = _currentConfig?['domain'] as String?;
          if (currentDomain == null || !urlStr.toLowerCase().contains(currentDomain.toLowerCase())) {
            _loadConfigForUrl(urlStr);
          }
        }
      },
      onLoadStop: (_, url) async {
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (url != null) _currentUrl = url.toString();
          });
        }
        _applyHidingAndScraping(force: true);
        _refreshNavButtons();
        // Dump HTML for offline analysis (dev tool, off by default — toggle via
        // the code icon in the app bar).
        _dumpHtml();
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        if (!mounted) return;
        setState(() {
          _loadError = error.description;
          _isLoading = false;
        });
        debugPrint('[webview] load error: ${error.type} ${error.description} ${request.url}');
      },
      onProgressChanged: (_, progress) {
        if (mounted) setState(() => _progress = progress / 100);
        if (progress > 50) _applyHidingAndScraping();
      },
      onUpdateVisitedHistory: (_, url, __) {
        if (url != null && mounted) {
          setState(() => _currentUrl = url.toString());
        }
        _refreshNavButtons();
      },
    );
  }

  Widget _buildLoadErrorOverlay() {
    final isDnsError = _loadError != null &&
        (_loadError!.contains('ERR_NAME_NOT_RESOLVED') ||
            _loadError!.toLowerCase().contains('name not resolved'));
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'error_occurred'.tr(),
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isDnsError
                  ? 'Check your internet connection. On Android emulators, DNS often breaks — try Cold Boot Now in AVD Manager, or test on a real device.'
                  : (_loadError ?? ''),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loadError = null);
                _webViewController?.reload();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('refresh'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(sizeFactor: anim, axisAlignment: 1, child: child),
      ),
      child: _isLoading
          ? Container(
              key: const ValueKey('loading'),
              padding: EdgeInsets.zero,
              color: AppColors.primarySurface.withOpacity(0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated progress strip
                  Stack(
                    children: [
                      Container(height: 3, color: AppColors.primary.withOpacity(0.12)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _progress.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.7),
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.45),
                                  blurRadius: 6,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Status row: dot pulse + "Loading … 42%"
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        _PulsingDot(color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'loading'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('idle')),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySurface.withOpacity(0.6),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom > 0 ? 8 : 12,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bottomNavButton(
            icon: Icons.arrow_back_rounded,
            enabled: _canGoBack,
            onTap: () => _webViewController?.goBack(),
            tooltip: 'back'.tr(),
          ),
          _bottomNavButton(
            icon: Icons.arrow_forward_rounded,
            enabled: _canGoForward,
            onTap: () => _webViewController?.goForward(),
            tooltip: 'forward'.tr(),
          ),
          _bottomNavButton(
            icon: Icons.refresh_rounded,
            enabled: true,
            onTap: () => _webViewController?.reload(),
            tooltip: 'refresh'.tr(),
          ),
          _bottomNavButton(
            icon: Icons.home_rounded,
            enabled: true,
            onTap: () => _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.initialUrl))),
            tooltip: 'home'.tr(),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Icon(
              icon,
              size: 24,
              color: enabled ? AppColors.textPrimary : AppColors.textHint.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  // Floating detected-product card with "Add to Cart"
  Widget _buildProductBar() {
    final img = (_currentProduct!['image_url'] ?? '').toString();
    final selectionSummary = (_currentProduct!['selection_summary'] ?? '').toString();
    final hasVariants = _currentProduct!['has_variants'] == true;
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: img.isNotEmpty
                  ? Image.network(img, width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentProduct!['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentProduct!['price'] ?? '',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.primary),
                  ),
                  if (selectionSummary.isNotEmpty)
                    Text(
                      selectionSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                    )
                  else if (hasVariants)
                    Text(
                      'select_options_hint'.tr(),
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.warning),
                    )
                  else
                    Text(
                      '${'from'.tr()} ${_currentProduct!['site'] ?? widget.siteName}',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _onAddToWishlist,
              icon: Icon(Icons.favorite_border, color: AppColors.error, size: 22),
              tooltip: 'add_to_wishlist'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _onAddToCart,
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: Text('add_to_cart'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.surfaceVariant,
      child: Icon(Icons.shopping_bag_outlined, color: AppColors.textHint, size: 22),
    );
  }
}

class _ProductSelectionSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> selections;
  final int initialQuantity;
  final bool requiresSelection;
  final String action;
  final Future<void> Function() onOpenNativePicker;

  const _ProductSelectionSheet({
    required this.product,
    required this.selections,
    required this.initialQuantity,
    required this.requiresSelection,
    required this.action,
    required this.onOpenNativePicker,
  });

  @override
  State<_ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<_ProductSelectionSheet> {
  late final Map<String, String> _chosen;
  late int _quantity;
  late final List<Map<String, dynamic>> _activeSelections;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity.clamp(1, 9999);
    _activeSelections = _WebViewScreenState._dedupeSelections(widget.selections);
    _chosen = {};
    for (final s in _activeSelections) {
      final name = (s['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final opts = _optionsFor(s);
      final value = (s['value'] ?? '').toString().trim();
      if (opts.length == 1) {
        _chosen[name] = opts.first;
      } else if (value.isNotEmpty) {
        _chosen[name] = value;
      }
    }
  }

  List<String> _optionsFor(Map<String, dynamic> sel) {
    final opts = <String>[];
    final raw = sel['options'];
    if (raw is List) {
      for (final o in raw) {
        final v = o.toString().trim();
        if (v.isNotEmpty && !opts.contains(v)) opts.add(v);
      }
    }
    final current = (sel['value'] ?? '').toString().trim();
    if (current.isNotEmpty && !opts.contains(current)) opts.insert(0, current);
    return opts;
  }

  bool get _canConfirm {
    for (final s in _activeSelections) {
      final opts = _optionsFor(s);
      if (opts.isEmpty) continue;
      if (opts.length == 1) continue;
      final name = (s['name'] ?? '').toString();
      if ((_chosen[name] ?? '').trim().isEmpty) return false;
    }
    return _quantity >= widget.initialQuantity.clamp(1, 9999);
  }

  List<Map<String, dynamic>> get _displaySelections {
    return _activeSelections.where((s) => _optionsFor(s).isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isCart = widget.action == 'cart';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'confirm_product_options'.tr(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              (widget.product['title'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (widget.requiresSelection) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.35)),
                ),
                child: Text(
                  'select_options_on_page_hint'.tr(),
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final sel in _displaySelections) ...[
                      Text(
                        (sel['name'] ?? '').toString(),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _optionsFor(sel).map((opt) {
                          final name = (sel['name'] ?? '').toString();
                          final selected = _chosen[name] == opt;
                          return ChoiceChip(
                            label: Text(opt),
                            selected: selected,
                            onSelected: (_) => setState(() => _chosen[name] = opt),
                            selectedColor: AppColors.primarySurface,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              color: selected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text('quantity'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_quantity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        if (widget.initialQuantity > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${'min_order'.tr()}: ${widget.initialQuantity}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.requiresSelection)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.onOpenNativePicker();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text('open_options_on_page'.tr()),
                ),
              ),
            if (widget.requiresSelection) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _canConfirm
                        ? () => Navigator.pop(context, {
                              'selections': _chosen,
                              'quantity': _quantity,
                            })
                        : null,
                    icon: Icon(isCart ? Icons.add_shopping_cart : Icons.favorite, size: 18),
                    label: Text(isCart ? 'add_to_cart'.tr() : 'add_to_wishlist'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCart ? AppColors.primary : AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.4 + 0.6 * t),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.35 * t),
                blurRadius: 8 * t,
                spreadRadius: 2 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinkSheet extends StatefulWidget {
  final String initialUrl;
  const _LinkSheet({required this.initialUrl});

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _controller.text = data.text!;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      });
    }
  }

  void _confirm() {
    final value = _controller.text.trim();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.travel_explore, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'search_by_link'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'search_by_link_desc'.tr(),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider, width: 0.6),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.link, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        hintText: 'paste_link'.tr(),
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _confirm(),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.cancel, size: 18, color: AppColors.textHint),
                      splashRadius: 18,
                      onPressed: () {
                        setState(() => _controller.clear());
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _ChipAction(
                  icon: Icons.content_paste_rounded,
                  label: 'paste'.tr(),
                  onTap: _paste,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'cancel'.tr(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _controller.text.trim().isEmpty ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'go'.tr(),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ChipAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

