import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/product.dart';
import '../services/backend_service.dart';
import 'cart_screen.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final BackendService _backendService = BackendService();
  InAppWebViewController? _webViewController;
  final TextEditingController _urlController = TextEditingController(
    text: 'https://www.amazon.sa/-/en/Sony-WH-1000XM4-Wireless-Cancelling-Over-Ear/dp/B08EC2D11V',
  );

  bool _isLoading = false;
  double _progress = 0.0;
  int _cartCount = 0;

  // Extracted product details
  Product? _currentProduct;
  Map<String, dynamic>? _currentConfig;

  // Search shortcuts
  final List<Map<String, String>> _shortcuts = [
    {
      'name': 'Amazon SA Product',
      'url': 'https://www.amazon.sa/-/en/Sony-WH-1000XM4-Wireless-Cancelling-Over-Ear/dp/B08EC2D11V',
    },
    {
      'name': 'Shein Product',
      'url': 'https://ar.shein.com/goods-p-32456488.html',
    },
  ];

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
  }

  Future<void> _refreshCartCount() async {
    final cart = await _backendService.fetchCart();
    if (mounted) {
      setState(() {
        _cartCount = cart.length;
      });
    }
  }

  // Load the css/js config from our backend based on target URL
  Future<void> _loadConfigForUrl(String url) async {
    final config = await _backendService.fetchScraperConfig(url);
    if (mounted) {
      setState(() {
        _currentConfig = config;
      });
    }
    _applyHidingAndScraping();
  }

  // Inject CSS to hide buy buttons and JS to scrape details
  void _applyHidingAndScraping() async {
    if (_webViewController == null || _currentConfig == null) return;

    final hideSelectors = List<String>.from(_currentConfig!['hide_selectors']);
    if (hideSelectors.isNotEmpty) {
      // 1. Inject CSS to hide buttons
      final css = hideSelectors.map((s) => "$s { display: none !important; visibility: hidden !important; pointer-events: none !important; }").join("\n");
      await _webViewController!.injectCSSCode(source: css);
      print("Injected CSS hiding selectors: ${hideSelectors.length}");
    }

    // 2. Inject JS Scraper Loop
    final titleSelector = _currentConfig!['title_selector'];
    final priceSelectorsJson = jsonEncode(_currentConfig!['price_selectors']);
    final imageSelectorsJson = jsonEncode(_currentConfig!['image_selectors']);
    final siteName = _currentConfig!['name'];

    final jsScraper = """
      (function() {
        function extractProduct() {
          try {
            const titleElem = document.querySelector("$titleSelector");
            if (!titleElem) return null;
            const title = titleElem.innerText.trim();
            if (!title) return null;

            const priceSelectors = $priceSelectorsJson;
            let price = "Unknown Price";
            for (const selector of priceSelectors) {
              const elem = document.querySelector(selector);
              if (elem) {
                const text = elem.innerText.trim();
                if (text) {
                  price = text;
                  break;
                }
              }
            }

            const imageSelectors = $imageSelectorsJson;
            let imageUrl = "";
            for (const selector of imageSelectors) {
              const elem = document.querySelector(selector);
              if (elem) {
                if (elem.src && elem.src.startsWith('http')) {
                  imageUrl = elem.src;
                } else if (elem.getAttribute("data-a-dynamic-image")) {
                  try {
                    const dyn = JSON.parse(elem.getAttribute("data-a-dynamic-image"));
                    imageUrl = Object.keys(dyn)[0];
                  } catch(e) {}
                }
                if (imageUrl) break;
              }
            }

            return {
              title: title,
              price: price,
              image_url: imageUrl,
              url: window.location.href,
              site: "$siteName"
            };
          } catch (e) {
            return null;
          }
        }

        // Periodic scraper loop
        if (!window._scraperIntervalId) {
          window._scraperIntervalId = setInterval(() => {
            const product = extractProduct();
            if (product) {
              window.flutter_inappwebview.callHandler('onProductDetected', product);
            }
          }, 1000);
        }
      })();
    """;

    await _webViewController!.evaluateJavascript(source: jsScraper);
    print("Injected JS Scraper loop.");
  }

  void _onAddToCart() async {
    if (_currentProduct == null) return;

    final result = await _backendService.addToCart(
      title: _currentProduct!.title,
      price: _currentProduct!.price,
      imageUrl: _currentProduct!.imageUrl,
      url: _currentProduct!.url,
      site: _currentProduct!.site,
    );

    if (result != null) {
      _refreshCartCount();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to your Application Cart!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.teal[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add to cart. Is backend server running?'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MVP Commerce Webview'),
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          // Cart Badge Icon
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, size: 28),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                  _refreshCartCount();
                },
              ),
              if (_cartCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Address Input Bar & Navigation Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey[100],
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await _webViewController?.canGoBack() ?? false) {
                      _webViewController?.goBack();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () async {
                    if (await _webViewController?.canGoForward() ?? false) {
                      _webViewController?.goForward();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    _webViewController?.reload();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Enter Product URL',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        var target = value;
                        if (!target.startsWith('http://') && !target.startsWith('https://')) {
                          target = 'https://$target';
                        }
                        _webViewController?.loadUrl(
                          urlRequest: URLRequest(url: WebUri(target)),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Shortcut Chips
          Container(
            height: 44,
            color: Colors.grey[100],
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _shortcuts.map((shortcut) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ActionChip(
                    label: Text(shortcut['name']!),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      _urlController.text = shortcut['url']!;
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(shortcut['url']!)),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          // Progress bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              color: Colors.indigo,
              backgroundColor: Colors.grey[200],
              minHeight: 3,
            ),
          // Web View container
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_urlController.text),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                    // Register the product detected Javascript handler
                    controller.addJavaScriptHandler(
                      handlerName: 'onProductDetected',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          final productData = Map<String, dynamic>.from(args[0]);
                          final product = Product(
                            id: '',
                            title: productData['title'] ?? 'Unknown Product',
                            price: productData['price'] ?? 'Unknown Price',
                            imageUrl: productData['image_url'] ?? '',
                            url: productData['url'] ?? '',
                            site: productData['site'] ?? 'External Web',
                          );
                          if (mounted && (_currentProduct == null || _currentProduct!.title != product.title || _currentProduct!.price != product.price)) {
                            setState(() {
                              _currentProduct = product;
                            });
                          }
                        }
                      },
                    );
                  },
                  onLoadStart: (controller, url) async {
                    setState(() {
                      _isLoading = true;
                      _currentProduct = null; // Clear old product on navigation
                      if (url != null) {
                        _urlController.text = url.toString();
                      }
                    });
                    if (url != null) {
                      await _loadConfigForUrl(url.toString());
                    }
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _isLoading = false;
                    });
                    _applyHidingAndScraping();
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                    if (progress > 50) {
                      _applyHidingAndScraping();
                    }
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) async {
                    if (url != null) {
                      final urlString = url.toString();
                      if (mounted) {
                        setState(() {
                          _urlController.text = urlString;
                          // Clear current product if the URL changed to avoid showing stale product details
                          if (_currentProduct != null && _currentProduct!.url != urlString) {
                            _currentProduct = null;
                          }
                        });
                      }
                      await _loadConfigForUrl(urlString);
                    }
                  },
                ),
                // Custom Native Floating Add-to-Cart Bar
                if (_currentProduct != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          // Thumbnail Image
                          if (_currentProduct!.imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _currentProduct!.imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image_not_supported, size: 20),
                                    ),
                              ),
                            )
                          else
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
                            ),
                          const SizedBox(width: 12),
                          // Title & Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentProduct!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentProduct!.price,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.indigo[700],
                                  ),
                                ),
                                Text(
                                  'From ${_currentProduct!.site}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Custom Native Add to Cart Button
                          ElevatedButton(
                            onPressed: _onAddToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.add_shopping_cart, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Add to Cart',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
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
