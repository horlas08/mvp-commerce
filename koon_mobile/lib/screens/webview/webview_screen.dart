import 'dart:async';
import 'dart:collection';
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
import '../../app/utils/scraper_helper.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String siteName;
  /// Optional variant pre-selections from a cart item.
  /// Keys are attribute names (e.g. "Color"), values are chosen options (e.g. "Red").
  /// When set, the WebView will automatically click the matching variant swatches
  /// after the product page has loaded.
  final Map<String, String>? preselectedVariants;
  final String? preselectedImageUrl;
  final DateTime? clickTime;

  final VoidCallback? onClose;

  const WebViewScreen({
    super.key,
    required this.initialUrl,
    required this.siteName,
    this.preselectedVariants,
    this.preselectedImageUrl,
    this.clickTime,
    this.onClose,
  });

  // ── Currency Cookie Setter (force SAR display on the website itself) ──────
  static Future<void> preloadAllCurrencyCookies() async {
    try {
      await Future.wait([
        setupCurrencyCookies('https://arabic.alibaba.com'),
        setupCurrencyCookies('https://ar.aliexpress.com'),
        setupCurrencyCookies('https://sa.iherb.com'),
        setupCurrencyCookies('https://www.amazon.sa'),
      ]);
    } catch (_) {}
  }

  static Future<void> setupCurrencyCookies(String url) async {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final cookieManager = CookieManager.instance();
      final expiresDate = DateTime.now()
          .add(const Duration(days: 365))
          .millisecondsSinceEpoch;

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
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "sc_g_cfg_f",
          value: "sc_b_currency=SAR&sc_b_locale=ar_SA&sc_b_site=SA",
          domain: ".alibaba.com",
          expiresDate: expiresDate,
          isSecure: true,
        );
      } else if (host.contains('aliexpress.com')) {
        final aliUri = WebUri(url);
        final aliCookies = [
          {
            'name': 'aep_usuc_f',
            'value':
                'site=ara&province=918500040000000000&city=918500040008000000&c_tp=SAR&x_alimid=2667132275&re_sns=google&isb=y&region=SA&b_locale=ar_MA&ae_u_p_s=2',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': false,
          },
          {
            'name': 'xman_us_f',
            'value':
                'zero_order=n&x_locale=ar_MA&x_l=1&x_user=NG|Qozeem|Monsurudeen|ifm|2667132275&x_lid=ng1068854275vggae&x_c_chg=1&acs_rt=1d74838ab3e849568d80ba731082fc4a&intl_locale=ar_MA',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': false,
          },
          {
            'name': 'xman_f',
            'value':
                'QS+jkqKaP1TapVVaifmkgFWL0HKOwi+QuclNqVEwGBuxOhhiwi5B4I+vLOR7zbwW171nImZs/UaPXV9Mr0/7KnxY4uPOLrfywPcakXfxMYv6Q+Xgq1s/NGyNwBfGIR/6KA6V1wcEnKbv+wxuRvSxGsJY/4RUa9Rb0Tvq5njkosBMwTfXOMXwU/U6HtEaQNbmLJlQT0+IgiwLqbLNb+Pdw2vcYGH1kUEQwVad4Vei+0CPb+D0qe4kV83xDLOeGLYxcy26w/qGU+o3TEF/7Jj35LTnPkhey3AIxAwULING0SyIkWWK9jgpRKppgWjGIkhAbH7+1nNC6Xv9oT3fnUAfhKHeXvx/QtnGB6Ud9RIH5J+ED+l5rFnahkjTgOf9r3tcu3yblLHLMBGvccPaBNOWPfiUTAMnadUI9HRBJo1CPf1bp5f9YoOcRAFEZu6EITA5scjjReiXGDkdXRQz04tjihssKJ1CNhvW',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': true,
          },
          {
            'name': 'xman_t',
            'value':
                'yjWbqSAMsU65GYww2edMxl2+8xc950nCmlCslJBj9cDXTKX3/l8qP3cw5h1bdlAJ',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': true,
          },
          {
            'name': '_baxia_sec_cookie_',
            'value':
                '%257B%2522lwrid%2522%253A%2522AgGfAKYbOyOG4DliUMXaxe5uIxeK%2522%252C%2522tfstk%2522%253A%2522gbWqMAv3idb5vQzhYMva8R6WRrpvBdzQ0OT6jGjMcEY0MC1yQaQVGV961A8GjU6Xli9mSGYPoAOf5O5-QMIOhop_DKIvBd4QRJaCDipOanrfqzsujhpwmnMCGFsvBd47RJwCDiQ4NYMuudqyEh-DjdvGS0qyjhgmsxbGqu8JrFvMINju4hLkSdvGSgqrp_ff1b-HiJvnhHxRWnR2-iYl5N6k02ThmUkiIlt2iQsDzADGU1CzilTUU4Y5jMCMaOzt5dI5TN5G-zGXo6-F8H_bExJGZaWetgUEHE5lkOJX9-up0_jeEE933mLhhhSMYpViqnXfN6OVarDwPtTJsTJaTmK53gXp_tUqEE7Rq69AKzHN-gsCHQBa84YOGHpkbOEn_FRG4iu9qzycBsuisIxJ4eZz4Uira_sgKOMZ6fdk838QDEht6IYB4eZz9fh9M-KyRo3F.%2522%252C%2522lwrtk%2522%253A%2522AAIEap9kDv0Fp1Edc6CWKcXc0Jb4UOtvK7tjdQNpyGyw45uTmwsUFPc%253D%2522%252C%2522epssw%2522%253A%252214*EItNc0ODDWbI-Wz4a3pxplcBNDZXR0znScPVQDp6oL4nDDDDi_lohDPPspt_B27B-6gxppB0Rw2-oskFqQHdLqjhPL4IlIjV95d0Fjru8z3HEb5vWhp_AC5SGHo3816uK0nS2nAHhs7iKs_tqJnTUTDDNnWETFzEC6GxDDd4oDDDYHV4DJ_tSuitlG8ZedIDWuDDh3_ltzjeAgpqApCzDdFADDDhBsooosEoo3yrEnoAdH8zM_s0pF0cgGFIUfF_TxuCU-hrRZ-DDWlhm0uVSN7d3uthn0g_dDQ_i57S8vODDPKdN0u-ixixMDu-PW52MLA9-yuIP938dBixMn8LMWj5MnD.%2522%257D',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': false,
          },
          {
            'name': 'aep_history',
            'value':
                'keywords%5E%0Akeywords%09%0A%0Aproduct_selloffer%5E%0Aproduct_selloffer%091005010510256569%091005007044095151%091005012569313705%091005006683803905',
            'domain': '.aliexpress.com',
            'isSecure': false,
            'isHttpOnly': false,
          },
          {
            'name': '_atrk_siteuid',
            'value': 'lwcwqYx-HkE0Fqr8',
            'domain': '.ar.aliexpress.com',
            'isSecure': false,
            'isHttpOnly': false,
          },
          {
            'name': 'g_state',
            'value':
                '{"i_l":0,"i_ll":1788801968375,"i_b":"a8P4lNtjX8v5c7DrftM2+GVj1fKX/KTUAf2aWT2nAH4","i_e":{"enable_itp_optimization":24},"i_et":1788801968375}',
            'domain': 'ar.aliexpress.com',
            'isSecure': false,
            'isHttpOnly': false,
          },
          {
            'name': 'isg',
            'value':
                'BOvrj99EBXcGrVmjIheYNKuEegnVAP-C59cCf11qYSio_A1e5daP0rbeUiSSZld6',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': false,
          },
          {
            'name': 'acs_usuc_t',
            'value':
                'x_csrf=qoo_svffd5cr&acs_rt=f37ed2cb916c4dca98059d13c4121c4a',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': false,
          },
          {
            'name': 'cna',
            'value': 'L4nEIlaGR1sCAWZdB0I+da2o',
            'domain': '.aliexpress.com',
            'isSecure': true,
            'isHttpOnly': false,
          },
        ];

        for (final c in aliCookies) {
          final domainStr = c['domain'] as String;
          final targetUri = domainStr.contains('ar.aliexpress.com')
              ? WebUri('https://ar.aliexpress.com')
              : aliUri;
          await cookieManager.setCookie(
            url: targetUri,
            name: c['name'] as String,
            value: c['value'] as String,
            domain: domainStr,
            path: '/',
            expiresDate: expiresDate,
            isSecure: c['isSecure'] as bool,
            isHttpOnly: c['isHttpOnly'] as bool,
          );
        }
      } else if (host.contains('iherb.com')) {
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "iher-pref1",
          value:
              "accsave=0&city=S1NBUklZ&ifv=1&lan=ar-SA&lchg=1&sccode=SA&scurcode=SAR&storeid=0&wp=2&zct=1782664399666",
          domain: ".iherb.com",
          expiresDate: expiresDate,
          isSecure: true,
        );
      } else if (host.contains('amazon.sa')) {
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "lc-acbsa",
          value: "ar_AE",
          domain: ".amazon.sa",
          expiresDate: expiresDate,
          isSecure: true,
        );
        await cookieManager.setCookie(
          url: WebUri(url),
          name: "i18n-prefs",
          value: "SAR",
          domain: ".amazon.sa",
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
  bool _isActionLoading = false;
  /// Prevents injecting pre-selections more than once per navigation.
  bool _preselectInjected = false;
  /// When iHerb navigates to a variant URL, this completer is set so that
  /// _handleProductAction can await the page load before re-extracting the price.
  Completer<void>? _pendingIherbNavCompleter;
  final ValueNotifier<Map<String, dynamic>?> _liveProductNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

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

  // ── Performance Profiling Timers ─────────────────────────────────────────
  DateTime? _initTime;
  DateTime? _createdTime;
  DateTime? _loadStartTime;
  DateTime? _firstProgressTime;
  int _lastReportedProgress = 0;
  DateTime? _loadStopTime;
  Timer? _progressFallbackTimer;

  String _timeFromClick([DateTime? target]) {
    final t = target ?? DateTime.now();
    final start = widget.clickTime ?? _initTime ?? t;
    return '+${t.difference(start).inMilliseconds}ms';
  }

  @override
  void initState() {
    super.initState();
    _initTime = DateTime.now();
    debugPrint('[PERF] 2. WEBVIEW_SCREEN initState: ${_timeFromClick(_initTime)} from card click');
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

    final scraperJs = ScraperHelper.buildScraperScript(_currentConfig!);
    await _webViewController!.evaluateJavascript(source: scraperJs);
  }

  // ── Cart helpers ─────────────────────────────────────────────────────────
  String _cartTypeForSite() {
    final name = widget.siteName.toLowerCase().replaceAll(' ', '');
    if (name.contains('amazon')) return 'amazon';
    if (name.contains('aliexpress')) return 'aliexpress';
    if (name.contains('alibaba')) return 'alibaba';
    if (name.contains('shein')) return 'shein';
    if (name.contains('iherb')) return 'iherb';
    return 'internal';
  }

  static bool _matchAttrName(String a, String b) {
    String clean(String s) {
      var t = s.trim().toLowerCase().replaceAll(RegExp(r'[:：]'), '').trim();
      t = t.replaceAll(RegExp(r'^(ال|al-?)', caseSensitive: false), '').trim();
      return t;
    }
    final ca = clean(a);
    final cb = clean(b);
    if (ca.isEmpty || cb.isEmpty) return false;
    if (ca == cb) return true;
    if ((ca.contains('لون') || ca.contains('color')) &&
        (cb.contains('لون') || cb.contains('color'))) return true;
    if ((ca.contains('حجم') || ca.contains('مقاس') || ca.contains('سعة') || ca.contains('size')) &&
        (cb.contains('حجم') || cb.contains('مقاس') || cb.contains('سعة') || cb.contains('size'))) return true;
    return false;
  }

  void _applyPreselectedVariantsToProduct(Map<String, dynamic> product) {
    final preselected = widget.preselectedVariants;
    if (preselected == null || preselected.isEmpty) return;
    if (_preselectInjected) return;

    final rawSelections = product['selections'];
    if (rawSelections is! List) return;

    final selections = _parseSelections(rawSelections);
    bool changed = false;
    final rawVariantImages = product['variant_images'];
    final variantImagesMap = (rawVariantImages is Map)
        ? Map<String, dynamic>.from(rawVariantImages)
        : <String, dynamic>{};

    for (final s in selections) {
      final name = (s['name'] ?? '').toString();
      for (final entry in preselected.entries) {
        if (_matchAttrName(entry.key, name)) {
          if (entry.value.isNotEmpty && s['value'] != entry.value) {
            s['value'] = entry.value;
            changed = true;
          }
          final opts = (s['options'] is List)
              ? List<String>.from((s['options'] as List).map((e) => e.toString()))
              : <String>[];
          if (!opts.contains(entry.value) && entry.value.isNotEmpty) {
            final rawSkuRegex = RegExp(r'^\d+(-\d+)+$');
            int replaceIdx = -1;
            for (int i = 0; i < opts.length; i++) {
              if (rawSkuRegex.hasMatch(opts[i])) {
                replaceIdx = i;
                break;
              }
            }
            if (replaceIdx >= 0) {
              final oldRaw = opts[replaceIdx];
              opts[replaceIdx] = entry.value;
              if (variantImagesMap.containsKey(oldRaw)) {
                variantImagesMap[entry.value] = variantImagesMap.remove(oldRaw);
              }
            } else {
              opts.add(entry.value);
            }
            s['options'] = opts;
            changed = true;
          }
          break;
        }
      }
    }

    if (changed) {
      product['selections'] = selections;
      product['variant_images'] = variantImagesMap;
      final summary = selections
          .where((s) => (s['value'] ?? '').toString().isNotEmpty)
          .map((s) => '${s['name']}: ${s['value']}')
          .join(' | ');
      if (summary.isNotEmpty) {
        product['selection_summary'] = summary;
      }
      for (final entry in preselected.entries) {
        final img = variantImagesMap[entry.value]?.toString();
        if (img != null && img.isNotEmpty) {
          product['image_url'] = img;
          break;
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchProductFromPage() async {
    if (_webViewController == null) return _currentProduct;
    try {
      final raw = await _webViewController!.evaluateJavascript(
        source:
            'window.__koonExtractProduct ? window.__koonExtractProduct() : null',
      );
      if (raw == null) return _currentProduct;
      final data = Map<String, dynamic>.from(raw as Map);
      _applyPreselectedVariantsToProduct(data);
      if (mounted) setState(() => _currentProduct = data);
      return data;
    } catch (_) {
      return _currentProduct;
    }
  }

  Future<Map<String, dynamic>?> _fetchIherbGrouping() async {
    if (_webViewController == null) return null;
    try {
      final raw = await _webViewController!.evaluateJavascript(
        source:
            'window.__koonGetIherbGrouping ? window.__koonGetIherbGrouping() : null',
      );
      if (raw == null || raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNativeSkuPicker() async {
    await _webViewController?.evaluateJavascript(
      source: 'window.__koonOpenSkuPicker && window.__koonOpenSkuPicker()',
    );
  }

  Future<Map<String, dynamic>?> _onSkuOptionSelected(
    String name,
    String value, [
    String? optImgUrl,
  ]) async {
    if (_webViewController == null) return null;
    try {
      final js =
          'window.__koonSelectOption ? window.__koonSelectOption(${jsonEncode(name)}, ${jsonEncode(value)}, ${jsonEncode(optImgUrl)}) : false';
      await _webViewController!.evaluateJavascript(source: js);
      // Wait for DOM transition/network to update the price/image
      // Amazon / AliExpress / Shein need ~800-1100ms, iHerb route transition needs ~1400ms
      if (_cartTypeForSite() == 'iherb') {
        await Future.delayed(const Duration(milliseconds: 1400));
      } else if (_cartTypeForSite() == 'amazon') {
        await Future.delayed(const Duration(milliseconds: 1200));
      } else {
        await Future.delayed(const Duration(milliseconds: 900));
      }
      // Re-scrape the product metadata from the page
      final data = await _fetchProductFromPage();
      if (data != null && mounted) {
        _liveProductNotifier.value = data;
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  String _buildExternalTitle(
    Map<String, dynamic> product,
    Map<String, String> chosenSelections,
  ) {
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
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      final rawProduct = await _fetchProductFromPage();
      if (rawProduct == null) return;
      Map<String, dynamic> product = rawProduct;

    final authController = Get.find<AuthController>();
    if (!authController.isLoggedIn.value) {
      // Show branded info snackbar (not error) prompting user to sign in
      _showInfoSnack('login_required_to_add'.tr(), icon: Icons.login_rounded);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (result != true) return;
    }

    final requiresSelection = product['requires_selection'] == true;
    List<Map<String, dynamic>> selections = _parseSelections(
      product['selections'],
    );

    Map<String, String>? chosen;
    final minQty = (product['min_quantity'] is num)
        ? (product['min_quantity'] as num).toInt()
        : 1;
    final pageQty = (product['selected_quantity'] is num)
        ? (product['selected_quantity'] as num).toInt()
        : 0;
    int quantity = pageQty > 0 ? pageQty : minQty;

    // iHerb: fetch navigation-based grouping (each variant = separate product URL).
    // Inject grouping options into the standard selections list so the same
    // _ProductSelectionSheet design is used — quantity selector and all.
    final isIherb = _cartTypeForSite() == 'iherb';
    // urlMap: option label → iHerb product URL (used for navigation after confirm)
    final Map<String, String> iherbUrlMap = {};

    if (isIherb) {
      final grouping = await _fetchIherbGrouping();
      final rawItems = grouping?['items'];
      final groupItems = (rawItems is List)
          ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      if (groupItems.isNotEmpty) {
        final groupName = (grouping?['name'] ?? '').toString();
        final currentSelected = (grouping?['selected'] ?? '').toString();
        final opts = <String>[];

        // Build variant images map from grouping thumbnails
        final Map<String, String> groupVariantImages = Map<String, String>.from(
          product['variant_images'] ?? {},
        );

        for (final item in groupItems) {
          final label = (item['label'] ?? '').toString();
          final url = (item['url'] ?? '').toString();
          final img = (item['image'] ?? '').toString();
          if (label.isEmpty) continue;
          opts.add(label);
          if (url.isNotEmpty) iherbUrlMap[label] = url;
          if (img.isNotEmpty && img.startsWith('http')) {
            groupVariantImages[label] = img;
          }
        }

        if (opts.isNotEmpty) {
          // Inject into selections — remove any existing grouping entry first
          selections = selections.where((s) {
            final n = (s['name'] ?? '').toString();
            return n != groupName;
          }).toList();
          selections.insert(0, {
            'name': groupName.isNotEmpty ? groupName : 'الخيار',
            'value': currentSelected,
            'options': opts,
          });
          // Patch variant images back into product so the sheet can show thumbnails
          product['variant_images'] = groupVariantImages;
        }
      }
    }

    // Always show the sheet for iHerb (or whenever there are real options / qty>1)
    if (isIherb ||
        requiresSelection ||
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
          onSelectOption: _onSkuOptionSelected,
          liveProductNotifier: _liveProductNotifier,
          preselectedVariants: widget.preselectedVariants,
        ),
      );
      if (result == null) return;
      chosen = Map<String, String>.from(result['selections'] as Map? ?? {});
      quantity = (result['quantity'] as num?)?.toInt() ?? quantity;
      if (result['product'] is Map) {
        product = Map<String, dynamic>.from(result['product'] as Map);
      }
      // Ensure we have the latest scraped price/image after sheet actions
      final latestScraped = await _fetchProductFromPage();
      if (latestScraped != null) {
        if (latestScraped['price'] != null &&
            latestScraped['price'].toString().isNotEmpty) {
          product['price'] = latestScraped['price'];
        }
        if (latestScraped['image_url'] != null &&
            latestScraped['image_url'].toString().isNotEmpty) {
          product['image_url'] = latestScraped['image_url'];
        }
      }

      // iHerb: if user picked a different pack/flavor option, navigate first
      // and WAIT for the new page to load before proceeding.
      if (isIherb && iherbUrlMap.isNotEmpty) {
        for (final entry in chosen.entries) {
          final targetUrl = iherbUrlMap[entry.value];
          if (targetUrl != null &&
              targetUrl.isNotEmpty &&
              !(_currentUrl.contains(targetUrl) ||
                  targetUrl.contains(_currentUrl))) {
            // Set up a completer that onLoadStop will resolve
            _pendingIherbNavCompleter = Completer<void>();
            _webViewController?.loadUrl(
              urlRequest: URLRequest(url: WebUri(targetUrl)),
            );
            // Wait for page load (timeout after 20s to avoid hanging forever)
            try {
              await _pendingIherbNavCompleter!.future.timeout(
                const Duration(seconds: 20),
                onTimeout: () {},
              );
            } catch (_) {}
            _pendingIherbNavCompleter = null;

            // Re-extract product info from the newly loaded page
            if (mounted && _webViewController != null) {
              await Future.delayed(const Duration(milliseconds: 800));
              final raw = await _webViewController!.evaluateJavascript(
                source: 'window.__koonExtractProduct ? window.__koonExtractProduct() : null',
              );
              if (raw != null && raw is Map) {
                product = Map<String, dynamic>.from(raw);
                product['url'] = targetUrl;
              }
            }
            // Continue adding to cart with updated product data below
            break;
          }
        }
      }
    }

    final finalTitle = _buildExternalTitle(
      product,
      chosen ?? _selectionsToMap(selections),
    );
    final cartType = _cartTypeForSite();
    final effectiveSelections = chosen ?? _selectionsToMap(selections);
    final String? selectionsJson = effectiveSelections.isNotEmpty
        ? jsonEncode(effectiveSelections)
        : null;

    if (action == 'cart') {
      final cartController = Get.find<CartController>();
      final result = await cartController.addToCart(
        cartType: cartType,
        title: finalTitle,
        price: product['price']?.toString(),
        imageUrl: product['image_url']?.toString(),
        externalUrl: product['url']?.toString(),
        siteName: product['site']?.toString() ?? widget.siteName,
        selectionsJson: selectionsJson,
        minQuantity: minQty,
        quantity: quantity,
      );
      if (result == AddToCartStatus.success) {
        _showActionSnack(true, 'added_to_cart'.tr());
      } else if (result == AddToCartStatus.unauthorized) {
        if (mounted) {
          final loginRes = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          if (loginRes == true) {
            _handleProductAction(action);
          }
        }
      } else {
        _showActionSnack(false, 'added_to_cart'.tr());
      }
    } else {
      final wishlistService = WishlistService();
      final res = await wishlistService.addToWishlist(
        externalUrl: product['url']?.toString(),
        title: finalTitle,
        price: product['price']?.toString(),
        imageUrl: product['image_url']?.toString(),
        source: cartType,
        selectionsJson: selectionsJson,
      );
      _showActionSnack(res != null, 'added_to_wishlist'.tr());
    }
  } finally {
    if (mounted) setState(() => _isActionLoading = false);
  }
}

  List<Map<String, dynamic>> _parseSelections(dynamic raw) {
    if (raw is! List) return [];
    return _dedupeSelections(
      raw.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }

  static String _normAttrName(String name) {
    return name
        .trim()
        .replaceAll(RegExp(r'\(\d+\)$'), '')
        .replaceAll(RegExp(r'[:：]\s*$'), '');
  }

  static List<Map<String, dynamic>> _dedupeSelections(
    List<Map<String, dynamic>> raw,
  ) {
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
    return merged.values
        .where((s) {
          final opts = s['options'] as List<String>;
          final value = (s['value'] ?? '').toString().trim();
          return opts.isNotEmpty || value.isNotEmpty;
        })
        .map((s) {
          final opts = s['options'] as List<String>;
          if ((s['value'] ?? '').toString().isEmpty && opts.length == 1) {
            s['value'] = opts.first;
          }
          return s;
        })
        .toList();
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
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              success ? message : 'error_occurred'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows a branded info snackbar (primary color) — used for prompts that are
  /// not errors, e.g. "Please sign in to add items to your cart".
  void _showInfoSnack(
    String message, {
    IconData icon = Icons.info_outline_rounded,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
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
    if (mounted)
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
  }

  void _navigateToUrl(String input) {
    var target = input.trim();
    if (target.isEmpty) return;
    final looksLikeUrl = target.contains('.') && !target.contains(' ');
    if (!looksLikeUrl) {
      target = 'https://www.google.com/search?q=${Uri.encodeComponent(target)}';
    } else if (!target.startsWith('http://') &&
        !target.startsWith('https://')) {
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
            Expanded(
              child: Text(
                'link_copied'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
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
    try {
      final cartController = Get.find<CartController>();
      cartController.selectedCartType.value = _cartTypeForSite();
    } catch (_) {}
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen(showBackButton: true)),
    );
  }

  // ── HTML dump helpers ────────────────────────────────────────────────────
  String _dumpSiteFolder() {
    final raw = widget.siteName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    return raw.replaceAll(RegExp(r'^_+|_+$'), '').isEmpty
        ? 'webview'
        : raw.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  // Counters for disambiguating repeated detail dumps (details_1, details_2…)
  static final Map<String, int> _dumpCounters = {};

  String _dumpFileNameFor(String url) {
    final folder = _dumpSiteFolder();
    final lc = url.toLowerCase();
    // Detect page type from URL
    final bool isDetail =
        lc.contains('/product-detail/') ||
        lc.contains('/detail/') ||
        RegExp(r'/item/\d+').hasMatch(lc) ||
        lc.contains('/dp/') ||
        lc.contains('/gp/product/') ||
        lc.contains('-p-') ||
        lc.contains('/goods-') ||
        lc.contains('/pd-') ||
        lc.contains('/pr/') || // iHerb product URL pattern
        lc.contains('product') ||
        lc.contains('item');
    final String pageType = isDetail ? 'details' : 'home';
    if (pageType == 'home') {
      return '${folder}_home';
    }
    final counterKey = '${folder}_details';
    _dumpCounters[counterKey] = (_dumpCounters[counterKey] ?? 0) + 1;
    final n = _dumpCounters[counterKey]!;
    return '${folder}_details_$n';
  }

  /// Injects pre-selected variant choices (from the originating cart item) into
  /// the page via the __koonSelectOption JS function.  Called once per page load.
  Future<void> _injectPreselectedVariants() async {
    final variants = widget.preselectedVariants;
    if (variants == null || variants.isEmpty) return;
    if (_preselectInjected) return;
    if (_webViewController == null) return;
    _preselectInjected = true;

    // Wait for the page's SKU/variant module to fully mount.
    // Most SPAs (AliExpress, Alibaba, Amazon) need ~800-1200ms after onLoadStop.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // First open the SKU picker (scrolls it into view / expands it).
    try {
      await _webViewController!.evaluateJavascript(
        source: 'window.__koonOpenSkuPicker ? window.__koonOpenSkuPicker() : false',
      );
      // Small pause for the picker animation to finish.
      await Future.delayed(const Duration(milliseconds: 400));
    } catch (_) {}

    // Click each variant option sequentially, with a pause between each to let
    // the page update (price/image/availability often reloads after each click).
    for (final entry in variants.entries) {
      if (!mounted) return;
      try {
        final name = entry.key;
        final value = entry.value;
        if (name.isEmpty || value.isEmpty) continue;
        final targetImg = _currentProduct?['image_url']?.toString() ??
            widget.preselectedImageUrl;
        final js =
            'window.__koonSelectOption ? window.__koonSelectOption(${jsonEncode(name)}, ${jsonEncode(value)}, ${jsonEncode(targetImg)}) : false';
        var res = await _webViewController!.evaluateJavascript(source: js);

        // JS may return 'probing' when async React-aware swatch probing was started.
        // Poll window.__koonProbeResult up to ~2s (13 × 150ms) for it to finish.
        if (res == 'probing') {
          for (int i = 0; i < 13; i++) {
            await Future.delayed(const Duration(milliseconds: 150));
            if (!mounted) return;
            final probeRes = await _webViewController!.evaluateJavascript(
              source: 'window.__koonProbeResult',
            );
            if (probeRes == true || probeRes == 1) {
              res = true;
              break;
            }
            if (probeRes == false) break; // done but no match – fall through to retry
            // null == still probing, keep waiting
          }
        }

        if (res != true && res != 1 && res != 'true') {
          // If not selected immediately, wait 600ms and retry once (for dynamic hydration)
          await Future.delayed(const Duration(milliseconds: 600));
          if (!mounted) return;
          await _webViewController!.evaluateJavascript(source: js);
        }
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (_) {}
    }

    // After pre-selection completes, refresh product extraction to sync live price/SKU
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _fetchProductFromPage();
    }
  }

  Future<void> _dumpHtml() async {
    if (!_dumpEnabled || _webViewController == null) return;
    try {
      // Pull the full DOM (including <html>/<head>/<body>) as a JSON-safe string.
      final raw = await _webViewController!.evaluateJavascript(
        source: "document.documentElement.outerHTML",
      );
      if (raw == null) return;
      final html = raw is String ? raw : raw.toString();

      Directory? baseDir;
      if (Platform.isAndroid) {
        // App-scoped external dir: /storage/emulated/0/Android/data/<pkg>/files/
        // Pullable via: adb pull <path> .   (no root, no extra permissions needed)
        baseDir = await getExternalStorageDirectory();
      }
      baseDir ??= await getApplicationDocumentsDirectory();

      // Create site-specific subfolder
      final siteFolder = _dumpSiteFolder();
      final dir = Directory('${baseDir.path}/$siteFolder');
      if (!dir.existsSync()) await dir.create(recursive: true);

      final fileName = _dumpFileNameFor(_currentUrl);
      final header =
          '<!-- Dumped ${DateTime.now().toIso8601String()} from $_currentUrl -->\n';
      final file = File('${dir.path}/$fileName.html');
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

  /// Absolute Mac path where ADB-pulled dumps should land, per site.
  /// Matches the `store_source/<site>/` folder structure in the project root.
  static const String _storeSourceRoot =
      '/Users/user/project/koon/store_source';

  Future<void> _showDumpInfo() async {
    final path = _lastDumpPath;
    final size = _lastDumpBytes;
    final when = _lastDumpAt;
    // Build the Mac destination: store_source/<site>/<filename>
    final siteFolder = _dumpSiteFolder();
    final fileName = path != null ? path.split('/').last : '';
    final macDest = '$_storeSourceRoot/$siteFolder/$fileName';
    final adbCommand = path != null
        ? 'adb pull "$path" "$_storeSourceRoot/$siteFolder/"'
        : '';
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
              const Text(
                'No dump yet. Reload the page to capture the current DOM.',
              )
            else ...[
              const Text(
                'Path:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              SelectableText(
                path,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              const SizedBox(height: 8),
              Text(
                'Size: ${_humanSize(size)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (when != null)
                Text(
                  'Last update: ${when.toLocal().toString().split('.').first}',
                  style: const TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Run on your Mac:\n$adbCommand\n\n→ saves to:\nstore_source/$siteFolder/$fileName',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (path != null) ...[
            TextButton.icon(
              icon: const Icon(Icons.terminal_rounded, size: 16),
              label: const Text('Copy ADB Pull'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: adbCommand));
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.terminal_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Copied → store_source/$siteFolder/$fileName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy device path'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device path copied to clipboard'),
                  ),
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: const Text('Copy Mac dest'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: macDest));
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mac destination path copied')),
                );
              },
            ),
          ],
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
        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          _webViewController!.goBack();
          return false;
        }
        if (widget.onClose != null) {
          widget.onClose!();
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
          children: [_buildLoadingBar(), _buildBottomNavBar()],
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
        onPressed: () {
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop();
          }
        },
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
        _appBarIcon(
          icon: Icons.code,
          onTap: _showDumpInfo,
          tooltip: 'HTML source dump',
        ),
        _appBarIcon(
          icon: Icons.share_outlined,
          onTap: _shareCurrentUrl,
          tooltip: 'share'.tr(),
        ),
        _appBarIcon(
          icon: Icons.travel_explore,
          onTap: _openLinkSheet,
          tooltip: 'search_by_link'.tr(),
        ),
        _buildCartIconWithBadge(),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _appBarIcon({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
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
    final siteCartType = _cartTypeForSite();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Obx(() {
        final count = cartController.getCountForCartType(siteCartType);
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
                  child: Icon(
                    Icons.shopping_basket_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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
      initialUrlRequest: null,
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: """
            (function() {
              'use strict';

              // 1. Force Arabic & SAR on document.cookie
              try {
                function forceArabicAndSar(cookieStr) {
                  if (!cookieStr || typeof cookieStr !== 'string') return cookieStr;
                  if (cookieStr.includes('aep_usuc_f=')) {
                    cookieStr = cookieStr.replace(/site=[a-zA-Z_]+/g, 'site=ara');
                    cookieStr = cookieStr.replace(/b_locale=[a-zA-Z_]+/g, 'b_locale=ar_MA');
                    cookieStr = cookieStr.replace(/c_tp=[a-zA-Z]+/g, 'c_tp=SAR');
                    cookieStr = cookieStr.replace(/region=[a-zA-Z]+/g, 'region=SA');
                  }
                  if (cookieStr.includes('xman_us_f=')) {
                    cookieStr = cookieStr.replace(/x_locale=[a-zA-Z_]+/g, 'x_locale=ar_MA');
                    cookieStr = cookieStr.replace(/intl_locale=[a-zA-Z_]+/g, 'intl_locale=ar_MA');
                  }
                  if (cookieStr.includes('sc_g_cfg_f=')) {
                    cookieStr = cookieStr.replace(/sc_b_locale=[a-zA-Z_]+/g, 'sc_b_locale=ar_SA');
                    cookieStr = cookieStr.replace(/sc_b_currency=[a-zA-Z]+/g, 'sc_b_currency=SAR');
                  }
                  if (window.location.hostname.includes('amazon.sa') || window.location.href.includes('amazon')) {
                    if (cookieStr.includes('lc-acbsa=')) {
                      cookieStr = cookieStr.replace(/lc-acbsa=[a-zA-Z_]+/g, 'lc-acbsa=ar_AE');
                    }
                    if (cookieStr.includes('i18n-prefs=')) {
                      cookieStr = cookieStr.replace(/i18n-prefs=[a-zA-Z_]+/g, 'i18n-prefs=SAR');
                    }
                  }
                  return cookieStr;
                }

                const originalCookieDescriptor = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie') ||
                                                 Object.getOwnPropertyDescriptor(HTMLDocument.prototype, 'cookie');

                if (originalCookieDescriptor && originalCookieDescriptor.set) {
                  Object.defineProperty(document, 'cookie', {
                    get: function() {
                      return originalCookieDescriptor.get.call(document);
                    },
                    set: function(val) {
                      originalCookieDescriptor.set.call(document, forceArabicAndSar(val));
                    },
                    configurable: true
                  });
                }
              } catch(e) {}

              // 2. Intercept & Clean Shein Dark Theme JSON Data before it executes
              function sanitizeTheme(themeObj) {
                if (!themeObj || typeof themeObj !== 'object') return;
                for (const k in themeObj) {
                  if (typeof themeObj[k] === 'string' && themeObj[k].toLowerCase().includes('dark')) {
                    themeObj[k] = '';
                  } else if (typeof themeObj[k] === 'object') {
                    sanitizeTheme(themeObj[k]);
                  }
                }
              }

              function sanitizeData(dataObj) {
                if (!dataObj || typeof dataObj !== 'object') return;
                if (dataObj.theme) sanitizeTheme(dataObj.theme);
                if (dataObj.info && dataObj.info.theme) sanitizeTheme(dataObj.info.theme);
                if (dataObj.productIntroData && dataObj.productIntroData.theme) sanitizeTheme(dataObj.productIntroData.theme);
                if (Array.isArray(dataObj.components)) {
                  for (const comp of dataObj.components) {
                    if (comp && comp.theme) sanitizeTheme(comp.theme);
                  }
                }
                if (Array.isArray(dataObj.elements)) {
                  for (const el of dataObj.elements) {
                    if (el && el.theme) sanitizeTheme(el.theme);
                  }
                }
                if (Array.isArray(dataObj.list)) {
                  for (const item of dataObj.list) {
                    if (item && item.fields && item.fields.theme) {
                      sanitizeTheme(item.fields.theme);
                    }
                    if (item && item.theme) {
                      sanitizeTheme(item.theme);
                    }
                  }
                }
              }

              // Intercept __STREAMING_DATA__
              let rawStreamingData = {};
              const streamingHandler = {
                set(target, prop, value) {
                  if (value && typeof value === 'object') {
                    sanitizeData(value);
                  }
                  target[prop] = value;
                  return true;
                }
              };
              const streamingProxy = new Proxy(rawStreamingData, streamingHandler);
              Object.defineProperty(window, '__STREAMING_DATA__', {
                get() { return streamingProxy; },
                set(val) {
                  if (val && typeof val === 'object') {
                    for (const k in val) {
                      streamingProxy[k] = val[k];
                    }
                  }
                },
                configurable: true
              });

              // Intercept __INIT_DATA__
              let rawInitData = null;
              Object.defineProperty(window, '__INIT_DATA__', {
                get() { return rawInitData; },
                set(val) {
                  if (val && typeof val === 'object') {
                    sanitizeData(val.data);
                  }
                  rawInitData = val;
                },
                configurable: true
              });

              // 3. Block and completely eliminate Alibaba & AliExpress Call-App popups/buttons/dialogs
              try {
                const antiCallAppCss = `
                  #call-app-dialog, .call-app-dialog, #call-app-button, .call-app-button,
                  .call-app-dialog-mask, .call-app-btn-overlay, .call-app-page-overlay,
                  .call-app-dialog-main, .ca-open,
                  [class*='call-app'], [id*='call-app'], [class*='callApp'], [id*='callApp'],
                  .no-mask-dialog, .weak-dialog, .weak-dialog-24, .medium-dialog,
                  .app-guide, .app-banner, .smart-banner, .smartbanner, .wakeup-app,
                  [class*='appGuide'], [class*='app-guide'], [class*='AppGuide'],
                  [class*='appBanner'], [class*='app-banner'], [class*='AppBanner'],
                  [class*='downloadApp'], [class*='download-app'], [class*='DownloadApp'],
                  [class*='openApp'], [class*='open-app'], [class*='OpenApp'],
                  [class*='openInApp'], [class*='open-in-app'], [class*='wakeApp'] {
                    display: none !important;
                    visibility: hidden !important;
                    opacity: 0 !important;
                    pointer-events: none !important;
                    width: 0 !important;
                    height: 0 !important;
                    max-height: 0 !important;
                    overflow: hidden !important;
                    position: fixed !important;
                    left: -99999px !important;
                    top: -99999px !important;
                    z-index: -99999 !important;
                  }
                `;

                function injectAntiCallAppStyle() {
                  if (document.getElementById('__anti_callapp_style__')) return;
                  const style = document.createElement('style');
                  style.id = '__anti_callapp_style__';
                  style.textContent = antiCallAppCss;
                  const root = document.head || document.documentElement || document.body;
                  if (root) root.appendChild(style);
                }

                injectAntiCallAppStyle();

                function dismissAndRemoveCallApp() {
                  injectAntiCallAppStyle();
                  const closeButtons = document.querySelectorAll(
                    '#call-app-dialog-close, .ca-close, [class*="call-app"] [class*="close"], [class*="callApp"] [class*="close"]'
                  );
                  closeButtons.forEach(btn => {
                    try { btn.click(); } catch(e) {}
                  });

                  const nodes = document.querySelectorAll(
                    '#call-app-dialog, .call-app-dialog, #call-app-button, .call-app-button, [class*="call-app"], [id*="call-app"], [class*="callApp"], [id*="callApp"]'
                  );
                  nodes.forEach(n => {
                    if (n.tagName && (n.tagName.toLowerCase() === 'body' || n.tagName.toLowerCase() === 'html')) return;
                    try { n.remove(); } catch(e) {}
                  });

                  if (document.body && document.body.style && document.body.style.overflow === 'hidden') {
                    document.body.style.overflow = '';
                  }
                  if (document.documentElement && document.documentElement.style && document.documentElement.style.overflow === 'hidden') {
                    document.documentElement.style.overflow = '';
                  }
                }

                dismissAndRemoveCallApp();
                if (window.MutationObserver) {
                  const callAppObserver = new MutationObserver(dismissAndRemoveCallApp);
                  callAppObserver.observe(document.documentElement || document, { childList: true, subtree: true });
                }
                document.addEventListener('DOMContentLoaded', dismissAndRemoveCallApp);
                window.addEventListener('load', dismissAndRemoveCallApp);
              } catch(e) {}
            })();
          """,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        )
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        cacheEnabled: true,
        cacheMode: CacheMode.LOAD_DEFAULT,
        hardwareAcceleration: true,
        loadsImagesAutomatically: true,
        allowsBackForwardNavigationGestures: true,
        transparentBackground: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        supportZoom: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
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
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*google-analytics\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*analytics\\.google\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*googletagmanager\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*doubleclick\\.net.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*clarity\\.ms.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          // Shein telemetry
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*srmdata\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          // Amazon telemetry & ads
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*unagi.*\\.amazon\\..*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*fls-.*\\.amazon\\..*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*amazon-adsystem\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          // AliExpress telemetry
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*aplus\\.aliexpress\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*fourier\\.aliexpress\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          // iHerb metrics & RUM
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*gtm-metrics\\.iherb\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*bam\\.nr-data\\.net.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*simonsignal\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          // Social tracking pixels & retargeting
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*connect\\.facebook\\.net.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*facebook\\.com/tr/.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*pinterest\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*bat\\.bing\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*tr\\.snapchat\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*alb\\.reddit\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*criteo\\.(com|net).*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*taboola\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*appier\\.net.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
          ContentBlocker(
            trigger: ContentBlockerTrigger(urlFilter: '.*zmaticoo\\.com.*'),
            action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
          ),
        ],
      ),
      onWebViewCreated: (controller) async {
        _createdTime = DateTime.now();
        final timeFromClick = _timeFromClick(_createdTime);
        final timeFromInit = _initTime != null ? '+${_createdTime!.difference(_initTime!).inMilliseconds}ms' : '';
        debugPrint('[PERF] 3. ON_WEBVIEW_CREATED (Controller ready): $timeFromClick from card click ($timeFromInit since initState)');
        _webViewController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'onProductDetected',
          callback: (args) {
            if (args.isNotEmpty) {
              if (args[0] == null) {
                if (mounted && _currentProduct != null) {
                  setState(() => _currentProduct = null);
                }
                return;
              }
              final data = Map<String, dynamic>.from(args[0]);
              _applyPreselectedVariantsToProduct(data);
              if (mounted) {
                _liveProductNotifier.value = data;
              }
              if (mounted &&
                  (_currentProduct == null ||
                      _currentProduct!['title'] != data['title'] ||
                      _currentProduct!['price'] != data['price'] ||
                      _currentProduct!['selection_summary'] !=
                          data['selection_summary'] ||
                      _currentProduct!['image_url'] != data['image_url'] ||
                      _currentProduct!['requires_selection'] !=
                          data['requires_selection'])) {
                setState(() => _currentProduct = data);
              }
            }
          },
        );
        await WebViewScreen.setupCurrencyCookies(widget.initialUrl);
        debugPrint('[PERF] 4. CALLING controller.loadUrl(${widget.initialUrl}): ${_timeFromClick()} from card click');
        await controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.initialUrl)));
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
      onPageCommitVisible: (_, url) {
        final timeFromClick = _timeFromClick();
        debugPrint('[PERF] 🚀 ON_PAGE_COMMIT_VISIBLE (First pixels rendered): $timeFromClick -> URL: $url');
        _applyHidingAndScraping();
      },
      onLoadStart: (_, url) {
        _progressFallbackTimer?.cancel();
        _progressFallbackTimer = null;
        _loadStartTime = DateTime.now();
        final timeFromClick = _timeFromClick(_loadStartTime);
        final timeFromCreated = _createdTime != null ? '+${_loadStartTime!.difference(_createdTime!).inMilliseconds}ms' : '';
        debugPrint('[PERF] 5. ON_LOAD_START (Browser engine network request begun): $timeFromClick from card click ($timeFromCreated since loadUrl) -> URL: $url');
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
          if (currentDomain == null ||
              !urlStr.toLowerCase().contains(currentDomain.toLowerCase())) {
            _loadConfigForUrl(urlStr);
          }
        }
      },
      onLoadStop: (_, url) async {
        _handlePageFinished(url, reason: 'onLoadStop');
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        if (!mounted) return;
        setState(() {
          _loadError = error.description;
          _isLoading = false;
        });
        debugPrint(
          '[webview] load error: ${error.type} ${error.description} ${request.url}',
        );
      },
      onProgressChanged: (_, progress) {
        final now = DateTime.now();
        if (_firstProgressTime == null && progress > 0) {
          _firstProgressTime = now;
          final timeFromClick = _timeFromClick(now);
          final timeFromLoadStart = _loadStartTime != null ? '+${now.difference(_loadStartTime!).inMilliseconds}ms' : '';
          debugPrint('>>> [PERF] 6. 🚀 FIRST PROGRESS BAR APPEARED ($progress%): $timeFromClick from card click ($timeFromLoadStart since load start)');
          debugPrint('>>>        (User waited $timeFromClick before seeing any progress bar!)');
        }

        if (progress == 100 || (progress - _lastReportedProgress) >= 20) {
          _lastReportedProgress = progress;
          debugPrint('[PERF] 7. PROGRESS $progress%: ${_timeFromClick(now)} from card click');
        }

        if (mounted) setState(() => _progress = progress / 100);
        if (progress > 50) _applyHidingAndScraping();

        if (progress >= 100) {
          _handlePageFinished(null, reason: 'progress 100%');
        } else if (progress >= 85) {
          // If stuck at 85-99% because of background analytics/trackers,
          // auto-complete gracefully after 750ms so user is never stuck.
          _progressFallbackTimer?.cancel();
          _progressFallbackTimer = Timer(const Duration(milliseconds: 750), () {
            if (mounted && _isLoading) {
              _handlePageFinished(null, reason: 'progress reached $progress% (auto-finish fallback)');
            }
          });
        }
      },
      onUpdateVisitedHistory: (_, url, __) {
        if (url != null && mounted) {
          setState(() => _currentUrl = url.toString());
        }
        _refreshNavButtons();
      },
    );
  }

  void _handlePageFinished(WebUri? url, {required String reason}) async {
    _progressFallbackTimer?.cancel();
    _progressFallbackTimer = null;

    if (!_isLoading && _progress >= 1.0) return;

    _loadStopTime = DateTime.now();
    final start = widget.clickTime ?? _initTime ?? _loadStopTime!;
    final totalMs = _loadStopTime!.difference(start).inMilliseconds;
    final tMount = _initTime != null ? _initTime!.difference(start).inMilliseconds : 0;
    final tCreated = (_createdTime != null && _initTime != null) ? _createdTime!.difference(_initTime!).inMilliseconds : 0;
    final tLoadStart = (_loadStartTime != null && _createdTime != null) ? _loadStartTime!.difference(_createdTime!).inMilliseconds : 0;
    final tFirstBar = (_firstProgressTime != null && _loadStartTime != null) ? _firstProgressTime!.difference(_loadStartTime!).inMilliseconds : 0;
    final tBarToEnd = (_firstProgressTime != null) ? _loadStopTime!.difference(_firstProgressTime!).inMilliseconds : 0;

    debugPrint('\n================ [PERF TIMELINE FINISHED] ================');
    debugPrint('[PERF] 8. PAGE READY ($reason)! URL: ${url ?? _currentUrl}');
    debugPrint('📊 SUMMARY BREAKDOWN:');
    debugPrint('   • [Card Tap -> Route Mount]:         ${tMount}ms');
    debugPrint('   • [Route Mount -> WebKit Ready]:      ${tCreated}ms');
    debugPrint('   • [WebKit Ready -> Load Started]:     ${tLoadStart}ms');
    debugPrint('   • [Load Started -> First Progress]:   ${tFirstBar}ms (Delay before progress bar showed)');
    debugPrint('   • [First Progress -> Finished]:       ${tBarToEnd}ms');
    debugPrint('   👉 TOTAL TIME (Tap to Finish):        ${(totalMs / 1000).toStringAsFixed(2)}s (${totalMs}ms)');
    debugPrint('==========================================================\n');

    if (mounted) {
      setState(() {
        _isLoading = false;
        _progress = 1.0;
        if (url != null) _currentUrl = url.toString();
        _preselectInjected = false;
      });
    }
    _applyHidingAndScraping(force: true);
    _refreshNavButtons();
    _dumpHtml();
    await _injectPreselectedVariants();

    // Resolve the iHerb navigation completer if it's pending
    if (_pendingIherbNavCompleter != null && !_pendingIherbNavCompleter!.isCompleted) {
      _pendingIherbNavCompleter!.complete();
    }
  }

  Widget _buildLoadErrorOverlay() {
    final isDnsError =
        _loadError != null &&
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
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isDnsError
                  ? 'Check your internet connection. On Android emulators, DNS often breaks — try Cold Boot Now in AVD Manager, or test on a real device.'
                  : (_loadError ?? ''),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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
                      Container(
                        height: 3,
                        color: AppColors.primary.withOpacity(0.12),
                      ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
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
            onTap: () => _webViewController?.loadUrl(
              urlRequest: URLRequest(url: WebUri(widget.initialUrl)),
            ),
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
              color: enabled
                  ? AppColors.textPrimary
                  : AppColors.textHint.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  // Floating detected-product card with "Add to Cart"
  Widget _buildProductBar() {
    final img = (_currentProduct!['image_url'] ?? '').toString();
    final selectionSummary = (_currentProduct!['selection_summary'] ?? '')
        .toString();
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: img.isNotEmpty
                  ? Image.network(
                      img,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
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
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentProduct!['price'] ?? '',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                  if (selectionSummary.isNotEmpty)
                    Text(
                      selectionSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else if (hasVariants)
                    Text(
                      'select_options_hint'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.warning,
                      ),
                    )
                  else
                    Text(
                      '${'from'.tr()} ${_currentProduct!['site'] ?? widget.siteName}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: _isActionLoading ? null : _onAddToWishlist,
              icon: _isActionLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : Icon(
                      Icons.favorite_border,
                      color: AppColors.error,
                      size: 22,
                    ),
              tooltip: 'add_to_wishlist'.tr(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _isActionLoading ? null : _onAddToCart,
                icon: _isActionLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_shopping_cart, size: 16),
                label: Text(
                  _isActionLoading ? 'loading'.tr() : 'add_to_cart'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
      child: Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.textHint,
        size: 22,
      ),
    );
  }

  @override
  void dispose() {
    _liveProductNotifier.dispose();
    _progressFallbackTimer?.cancel();
    _progressFallbackTimer = null;
    super.dispose();
  }
}

class _ProductSelectionSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> selections;
  final int initialQuantity;
  final bool requiresSelection;
  final String action;
  final Future<void> Function() onOpenNativePicker;
  final Future<Map<String, dynamic>?> Function(String name, String value, [String? optImgUrl])
  onSelectOption;
  final ValueNotifier<Map<String, dynamic>?>? liveProductNotifier;
  final Map<String, String>? preselectedVariants;

  const _ProductSelectionSheet({
    required this.product,
    required this.selections,
    required this.initialQuantity,
    required this.requiresSelection,
    required this.action,
    required this.onOpenNativePicker,
    required this.onSelectOption,
    this.liveProductNotifier,
    this.preselectedVariants,
  });

  @override
  State<_ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<_ProductSelectionSheet> {
  late final Map<String, String> _chosen;
  late int _quantity;
  late final List<Map<String, dynamic>> _activeSelections;
  late final Map<String, String> _variantImages;
  String? _currentVariantImage;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity.clamp(1, 9999);
    _activeSelections = _WebViewScreenState._dedupeSelections(
      widget.selections,
    );
    // Extract variant_images map from the product data
    final rawVariantImages = widget.product['variant_images'];
    _variantImages = rawVariantImages is Map
        ? Map<String, String>.from(
            rawVariantImages.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ),
          )
        : {};
    _chosen = {};
    for (final s in _activeSelections) {
      final name = (s['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final opts = _optionsFor(s);
      final value = (s['value'] ?? '').toString().trim();

      String? preselectedVal;
      if (widget.preselectedVariants != null) {
        for (final entry in widget.preselectedVariants!.entries) {
          if (_WebViewScreenState._matchAttrName(entry.key, name)) {
            preselectedVal = entry.value;
            break;
          }
        }
      }

      if (preselectedVal != null && preselectedVal.isNotEmpty) {
        _chosen[name] = preselectedVal;
        if (!opts.contains(preselectedVal)) {
          final rawSkuRegex = RegExp(r'^\d+(-\d+)+$');
          int replaceIdx = -1;
          for (int i = 0; i < opts.length; i++) {
            if (rawSkuRegex.hasMatch(opts[i])) {
              replaceIdx = i;
              break;
            }
          }
          if (replaceIdx >= 0) {
            final oldRaw = opts[replaceIdx];
            opts[replaceIdx] = preselectedVal;
            if (_variantImages.containsKey(oldRaw)) {
              _variantImages[preselectedVal] = _variantImages.remove(oldRaw)!;
            }
          } else {
            // Only append the preselected value as a new option if the existing
            // options are text-only (no variant images). If all opts have images,
            // it means the page uses image-based swatches — adding a text-only
            // pill would look broken next to them.
            final allHaveImages = opts.isNotEmpty &&
                opts.every((o) => _variantImages.containsKey(o));
            if (!allHaveImages) {
              opts.add(preselectedVal);
            }
            // Either way, still mark it as chosen so JS selection tries to activate it.
          }
          s['options'] = opts;
        }
        s['value'] = preselectedVal;
      } else if (opts.length == 1) {
        _chosen[name] = opts.first;
      } else if (value.isNotEmpty) {
        _chosen[name] = value;
      }
    }
    _updateVariantImage();
    widget.liveProductNotifier?.addListener(_onLiveProductUpdated);
  }

  @override
  void dispose() {
    widget.liveProductNotifier?.removeListener(_onLiveProductUpdated);
    super.dispose();
  }

  void _onLiveProductUpdated() {
    final updated = widget.liveProductNotifier?.value;
    if (updated == null || !mounted) return;
    setState(() {
      _syncWithUpdatedProduct(updated);
    });
  }

  void _syncWithUpdatedProduct(Map<String, dynamic> updated) {
    if (updated['price'] != null && updated['price'].toString().isNotEmpty) {
      widget.product['price'] = updated['price'];
    }
    if (updated['title'] != null && updated['title'].toString().isNotEmpty) {
      widget.product['title'] = updated['title'];
    }
    final imgUrl = updated['image_url']?.toString();
    if (imgUrl != null && imgUrl.isNotEmpty) {
      widget.product['image_url'] = imgUrl;
      _currentVariantImage = imgUrl;
    }
    final rawVariantImages = updated['variant_images'];
    if (rawVariantImages is Map) {
      rawVariantImages.forEach((k, v) {
        if (k != null && v != null) {
          _variantImages[k.toString()] = v.toString();
        }
      });
    }
    final rawSelections = updated['selections'];
    if (rawSelections is List && rawSelections.isNotEmpty) {
      final newSelections = _WebViewScreenState._dedupeSelections(
        rawSelections.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );

      // Preserve stable ordering of groups and existing options
      for (final newSel in newSelections) {
        final newName = (newSel['name'] ?? '').toString().trim();
        if (newName.isEmpty) continue;

        final existingIndex = _activeSelections.indexWhere(
          (s) =>
              (s['name'] ?? '').toString().trim().toLowerCase() ==
              newName.toLowerCase(),
        );

        if (existingIndex >= 0) {
          final existing = _activeSelections[existingIndex];
          final newVal = (newSel['value'] ?? '').toString().trim();
          if (newVal.isNotEmpty) {
            existing['value'] = newVal;
          }
          final existingOpts = _optionsFor(existing);
          final incomingOpts = _optionsFor(newSel);
          final rawSkuRegex = RegExp(r'^\d+(-\d+)+$');
          for (final inc in incomingOpts) {
            if (!existingOpts.contains(inc)) {
              if (!rawSkuRegex.hasMatch(inc)) {
                final rawIdx = existingOpts.indexWhere((e) => rawSkuRegex.hasMatch(e));
                if (rawIdx >= 0) {
                  final old = existingOpts[rawIdx];
                  existingOpts[rawIdx] = inc;
                  if (_variantImages.containsKey(old)) {
                    _variantImages[inc] = _variantImages.remove(old)!;
                  }
                  continue;
                }
              }
              existingOpts.add(inc);
            }
          }
          existing['options'] = existingOpts;
        } else {
          _activeSelections.add(newSel);
        }
      }

      for (final s in _activeSelections) {
        final sName = (s['name'] ?? '').toString();
        final sVal = (s['value'] ?? '').toString().trim();
        final sOpts = _optionsFor(s);
        if (_isUpdating && sVal.isNotEmpty) {
          _chosen[sName] = sVal;
        } else if (!_chosen.containsKey(sName) || (_chosen[sName] != null && !sOpts.contains(_chosen[sName]))) {
          if (sVal.isNotEmpty) {
            _chosen[sName] = sVal;
          } else if (sOpts.isNotEmpty) {
            _chosen[sName] = sOpts.first;
          }
        }
      }
    }
    _updateVariantImage();
  }

  void _updateVariantImage() {
    // Find the first chosen option that has a variant image
    for (final entry in _chosen.entries) {
      final img = _variantImages[entry.value];
      if (img != null && img.isNotEmpty) {
        _currentVariantImage = img;
        return;
      }
    }
    final mainImg = widget.product['image_url']?.toString();
    _currentVariantImage = (mainImg != null && mainImg.isNotEmpty) ? mainImg : null;
  }

  String _getUpdatedPriceString(String priceRaw, int quantity) {
    if (priceRaw.isEmpty) return '';
    final match = RegExp(r'([0-9.,]+)').firstMatch(priceRaw);
    if (match == null) return priceRaw;

    var numStr = match.group(1)!;
    if (numStr.contains('-') || priceRaw.contains('-')) {
      return priceRaw;
    }

    // Clean leading/trailing dots/commas
    while (numStr.startsWith('.') || numStr.startsWith(',')) {
      numStr = numStr.substring(1);
    }
    while (numStr.endsWith('.') || numStr.endsWith(',')) {
      numStr = numStr.substring(0, numStr.length - 1);
    }

    try {
      double? val;
      if (numStr.contains(',') && numStr.contains('.')) {
        if (numStr.lastIndexOf(',') > numStr.lastIndexOf('.')) {
          val = double.tryParse(numStr.replaceAll('.', '').replaceAll(',', '.'));
        } else {
          val = double.tryParse(numStr.replaceAll(',', ''));
        }
      } else if (numStr.contains(',')) {
        final parts = numStr.split(',');
        if (parts.length > 2 || (parts.length == 2 && parts.last.length == 3)) {
          val = double.tryParse(numStr.replaceAll(',', ''));
        } else {
          val = double.tryParse(numStr.replaceAll(',', '.'));
        }
      } else if (numStr.contains('.')) {
        final parts = numStr.split('.');
        if (parts.length > 2) {
          val = double.tryParse(numStr.replaceAll('.', ''));
        } else {
          val = double.tryParse(numStr);
        }
      } else {
        val = double.tryParse(numStr);
      }

      if (val != null) {
        final total = val * quantity;
        final prefix = priceRaw.substring(0, match.start);
        final suffix = priceRaw.substring(match.end);

        String formattedVal;
        if (numStr.contains('.')) {
          final decimalPlaces = numStr.split('.').last.length;
          formattedVal = total.toStringAsFixed(decimalPlaces);
        } else if (numStr.contains(',')) {
          final decimalPlaces = numStr.split(',').last.length;
          formattedVal = total
              .toStringAsFixed(decimalPlaces)
              .replaceAll('.', ',');
        } else {
          formattedVal = total.toStringAsFixed(0);
        }

        if (numStr.contains(',') && numStr.contains('.')) {
          final parts = formattedVal.split('.');
          final whole = parts[0];
          final decimal = parts.length > 1 ? '.' + parts[1] : '';
          final sb = StringBuffer();
          for (var i = 0; i < whole.length; i++) {
            if (i > 0 && (whole.length - i) % 3 == 0) {
              sb.write(',');
            }
            sb.write(whole[i]);
          }
          formattedVal = sb.toString() + decimal;
        }

        return '$prefix$formattedVal$suffix';
      }
    } catch (_) {}
    return priceRaw;
  }

  void _selectOption(String name, String opt) async {
    if (_isUpdating) return;
    final optImg = _variantImages[opt] ?? widget.product['image_url']?.toString();
    setState(() {
      _chosen[name] = opt;
      _updateVariantImage();
      _isUpdating = true;
    });
    try {
      final updatedProduct = await widget.onSelectOption(name, opt, optImg);
      if (updatedProduct != null && mounted) {
        setState(() {
          _syncWithUpdatedProduct(updatedProduct);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
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
    if (current.isNotEmpty && !opts.contains(current)) {
      final rawSkuRegex = RegExp(r'^\d+(-\d+)+$');
      if (!rawSkuRegex.hasMatch(current)) {
        final rawIdx = opts.indexWhere((o) => rawSkuRegex.hasMatch(o));
        if (rawIdx >= 0) {
          opts[rawIdx] = current;
        } else {
          opts.add(current);
        }
      } else {
        opts.add(current);
      }
    }
    return opts;
  }

  bool get _canConfirm {
    if (_isUpdating) return false;
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
    final mainImg = (widget.product['image_url'] ?? '').toString();
    final displayImg = (_currentVariantImage?.isNotEmpty == true)
        ? _currentVariantImage!
        : mainImg;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
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
            // Product header: image + title/price row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ClipRRect(
                    key: ValueKey(displayImg),
                    borderRadius: BorderRadius.circular(12),
                    child: displayImg.isNotEmpty
                        ? Image.network(
                            displayImg,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _sheetImagePlaceholder(),
                          )
                        : _sheetImagePlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'confirm_product_options'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (widget.product['title'] ?? '').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _getUpdatedPriceString(
                              (widget.product['price'] ?? '').toString(),
                              _quantity,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (_isUpdating) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.requiresSelection) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  'select_options_on_page_hint'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
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
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _optionsFor(sel).map((opt) {
                          final name = (sel['name'] ?? '').toString();
                          final selected = _chosen[name] == opt;
                          final hasVariantImg = _variantImages.containsKey(opt);
                          return GestureDetector(
                            onTap: _isUpdating ? null : () => _selectOption(name, opt),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: hasVariantImg
                                  ? const EdgeInsets.all(2)
                                  : const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primarySurface
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                  hasVariantImg ? 10 : 20,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: hasVariantImg
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            _variantImages[opt]!,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 48,
                                              height: 48,
                                              color: AppColors.surfaceVariant,
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                size: 20,
                                                color: AppColors.textHint,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 52,
                                          child: Text(
                                            opt,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      opt,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'quantity'.tr(),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_quantity',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        if (widget.initialQuantity > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${'min_order'.tr()}: ${widget.initialQuantity}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
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
                    onPressed: (_canConfirm && !_isUpdating)
                        ? () => Navigator.pop(context, {
                            'selections': _chosen,
                            'quantity': _quantity,
                            'product': widget.product,
                          })
                        : null,
                    icon: _isUpdating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isCart ? Icons.add_shopping_cart : Icons.favorite,
                            size: 18,
                          ),
                    label: Text(
                      _isUpdating
                          ? 'loading'.tr()
                          : (isCart ? 'add_to_cart'.tr() : 'add_to_wishlist'.tr()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCart
                          ? AppColors.primary
                          : AppColors.error,
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

  Widget _sheetImagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.textHint,
        size: 28,
      ),
    );
  }
}

// ── iHerb Grouping Sheet ───────────────────────────────────────────────────
// Shows pack-size / flavor options scraped from iHerb's product-grouping UI.
// Each option has a URL; tapping it navigates the webview and closes the sheet.
class _IherbGroupingSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String groupingName;
  final List<Map<String, dynamic>> groupItems;
  final String action;
  final void Function(String url) onNavigate;

  const _IherbGroupingSheet({
    required this.product,
    required this.groupingName,
    required this.groupItems,
    required this.action,
    required this.onNavigate,
  });

  @override
  State<_IherbGroupingSheet> createState() => _IherbGroupingSheetState();
}

class _IherbGroupingSheetState extends State<_IherbGroupingSheet> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Default to whichever item is marked selected (current URL)
    _selectedIndex = widget.groupItems.indexWhere((g) => g['selected'] == true);
    if (_selectedIndex < 0) _selectedIndex = 0;
  }

  bool get _hasImages => widget.groupItems.any((g) {
    final img = (g['image'] ?? '').toString();
    return img.isNotEmpty && img.startsWith('http');
  });

  @override
  Widget build(BuildContext context) {
    final isCart = widget.action == 'cart';
    final productImg = (widget.product['image_url'] ?? '').toString();
    final productTitle = (widget.product['title'] ?? '').toString();
    final productPrice = (widget.product['price'] ?? '').toString();
    final selectedItem = widget.groupItems[_selectedIndex];
    final selectedLabel = (selectedItem['label'] ?? '').toString();
    final selectedUrl = (selectedItem['url'] ?? '').toString();
    final selectedImg = (selectedItem['image'] ?? '').toString();
    final displayImg =
        (selectedImg.isNotEmpty && selectedImg.startsWith('http'))
        ? selectedImg
        : productImg;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
            // Product header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: ClipRRect(
                    key: ValueKey(displayImg),
                    borderRadius: BorderRadius.circular(12),
                    child: displayImg.isNotEmpty
                        ? Image.network(
                            displayImg,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'confirm_product_options'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        productPrice,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Grouping name
            Text(
              widget.groupingName.isNotEmpty
                  ? widget.groupingName
                  : 'الخيارات المتاحة',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            // Options grid
            Flexible(
              child: SingleChildScrollView(
                child: _hasImages ? _buildImageGrid() : _buildTextChips(),
              ),
            ),
            const SizedBox(height: 16),
            // Confirm + Navigate row
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
                    onPressed: selectedUrl.isNotEmpty
                        ? () {
                            widget.onNavigate(selectedUrl);
                            Navigator.pop(context, true);
                          }
                        : null,
                    icon: Icon(
                      isCart ? Icons.add_shopping_cart : Icons.favorite,
                      size: 18,
                    ),
                    label: Text(
                      selectedLabel.isNotEmpty
                          ? (isCart
                                ? 'add_to_cart'.tr()
                                : 'add_to_wishlist'.tr())
                          : 'select_options_hint'.tr(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCart
                          ? AppColors.primary
                          : AppColors.error,
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

  Widget _buildImageGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(widget.groupItems.length, (i) {
        final item = widget.groupItems[i];
        final label = (item['label'] ?? '').toString();
        final img = (item['image'] ?? '').toString();
        final price = (item['price'] ?? '').toString();
        final selected = i == _selectedIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primarySurface
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (img.isNotEmpty && img.startsWith('http'))
                      ? Image.network(
                          img,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: AppColors.surfaceVariant,
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 24,
                              color: AppColors.textHint,
                            ),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: AppColors.surfaceVariant,
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 24,
                            color: AppColors.textHint,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                if (price.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    price,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTextChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(widget.groupItems.length, (i) {
        final item = widget.groupItems[i];
        final label = (item['label'] ?? '').toString();
        final price = (item['price'] ?? '').toString();
        final selected = i == _selectedIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primarySurface
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                if (price.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.local_pharmacy_outlined,
        color: AppColors.textHint,
        size: 28,
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

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  child: Icon(
                    Icons.travel_explore,
                    color: AppColors.primary,
                    size: 20,
                  ),
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
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        hintText: 'paste_link'.tr(),
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _confirm(),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.cancel,
                        size: 18,
                        color: AppColors.textHint,
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    onPressed: _controller.text.trim().isEmpty
                        ? null
                        : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withOpacity(
                        0.4,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  const _ChipAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
