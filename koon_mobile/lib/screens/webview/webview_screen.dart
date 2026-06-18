import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/api_service.dart';
import '../../app/constants/api_constants.dart';
import '../auth/login_screen.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String siteName;

  const WebViewScreen({
    super.key,
    required this.initialUrl,
    required this.siteName,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = false;
  double _progress = 0.0;
  Map<String, dynamic>? _currentConfig;
  Map<String, dynamic>? _currentProduct;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadConfigForUrl(String url) async {
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

  void _applyHidingAndScraping() async {
    if (_webViewController == null || _currentConfig == null) return;

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
        if (!window._hideObserver) {
          window._hideObserver = new MutationObserver(() => { hideElements(); });
          window._hideObserver.observe(document.documentElement, { childList: true, subtree: true, attributes: false });
        }
        if (!window._hideIntervalId) {
          hideElements();
          window._hideIntervalId = setInterval(hideElements, 800);
        } else {
          hideElements();
        }
        function extractProduct() {
          try {
            const titleElem = document.querySelector("$titleSelector");
            if (!titleElem) return null;
            const title = titleElem.textContent.trim();
            if (!title) return null;
            const priceSelectors = $priceSelectorsJson;
            let price = "Unknown Price";
            for (const selector of priceSelectors) {
              const elem = document.querySelector(selector);
              if (elem) { const text = elem.textContent.trim(); if (text) { price = text; break; } }
            }
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
            return { title: title, price: price, image_url: imageUrl, url: window.location.href, site: "$siteName" };
          } catch (e) { return null; }
        }
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

  Future<void> _onAddToCart() async {
    if (_currentProduct == null) return;
    final authController = Get.find<AuthController>();
    if (!authController.isLoggedIn.value) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (result != true) return;
    }

    final cartController = Get.find<CartController>();
    final cartType = widget.siteName.toLowerCase().replaceAll(' ', '');
    final success = await cartController.addToCart(
      cartType: cartType == 'amazonsa' ? 'amazon' : cartType,
      title: _currentProduct!['title'],
      price: _currentProduct!['price'],
      imageUrl: _currentProduct!['image_url'],
      externalUrl: _currentProduct!['url'],
      siteName: _currentProduct!['site'],
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Added to your cart!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.siteName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () async {
            if (await _webViewController?.canGoBack() ?? false) _webViewController?.goBack();
          }),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => _webViewController?.reload()),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress, color: AppColors.primary, backgroundColor: AppColors.surfaceVariant, minHeight: 3),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    transparentBackground: true,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'onProductDetected',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          final data = Map<String, dynamic>.from(args[0]);
                          if (mounted && (_currentProduct == null || _currentProduct!['title'] != data['title'])) {
                            setState(() => _currentProduct = data);
                          }
                        }
                      },
                    );
                  },
                  onLoadStart: (_, url) async {
                    setState(() { _isLoading = true; _currentProduct = null; });
                    if (url != null) await _loadConfigForUrl(url.toString());
                  },
                  onLoadStop: (_, __) { setState(() => _isLoading = false); _applyHidingAndScraping(); },
                  onProgressChanged: (_, progress) {
                    setState(() => _progress = progress / 100);
                    if (progress > 50) _applyHidingAndScraping();
                  },
                ),
                if (_currentProduct != null)
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 15, offset: const Offset(0, 5))],
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          if (_currentProduct!['image_url'] != null && _currentProduct!['image_url'].toString().isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(_currentProduct!['image_url'], width: 50, height: 50, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: AppColors.surfaceVariant)),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_currentProduct!['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(_currentProduct!['price'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: _onAddToCart,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
