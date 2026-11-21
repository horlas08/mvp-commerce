import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'dart:convert';
import '../../app/theme/app_colors.dart';
import '../../app/utils/app_snackbar.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/compare_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/wishlist_service.dart';
import '../../services/product_service.dart';
import '../auth/login_screen.dart';
import '../sellers/seller_shop_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final CartController _cartController = Get.find<CartController>();
  final CompareController _compareController = Get.find<CompareController>();
  final SettingsController _settingsController = Get.find<SettingsController>();
  final AuthController _authController = Get.find<AuthController>();
  final WishlistService _wishlistService = WishlistService();
  final ProductService _productService = ProductService();

  late Map<String, dynamic> _product;
  int _currentImageIndex = 0;
  bool _isWishlisted = false;
  String? _wishlistItemId;
  bool _loadingWishlist = true;

  // Variants state
  final Map<String, String> _selectedVariants = {};
  double? _variantPriceOverride;
  int? _variantStockOverride;

  // Description / Reviews Tab state (Matches User Image 2)
  int _selectedTab = 0; // 0 = Description ("وصف المنتج"), 1 = Reviews ("التعليقات")

  // Similar Products state
  List<Map<String, dynamic>> _similarProducts = [];
  bool _loadingSimilar = true;

  @override
  void initState() {
    super.initState();
    _product = Map<String, dynamic>.from(widget.product);
    _initVariants();
    _checkWishlistStatus();
    _loadSimilarProducts();
    _fetchFullProduct();
  }

  Future<void> _fetchFullProduct() async {
    final id = _product['id']?.toString();
    if (id == null) return;
    try {
      final lang = Get.locale?.languageCode ?? 'en';
      final full = await _productService.getProduct(id, lang: lang);
      if (full != null && mounted) {
        setState(() {
          _product = full;
          _initVariants();
        });
      }
    } catch (_) {
      // Keep existing data
    }
  }

  void _initVariants() {
    final variants = _getVariantsList();
    for (var v in variants) {
      final type = v['type']?.toString() ?? '';
      final options = (v['options'] as List?) ?? [];
      if (type.isNotEmpty && options.isNotEmpty) {
        if (!_selectedVariants.containsKey(type) || _selectedVariants[type]!.isEmpty) {
          final firstOpt = options.first;
          final optName = firstOpt is Map ? firstOpt['name']?.toString() ?? '' : firstOpt.toString();
          _selectedVariants[type] = optName;
        }
      }
    }
    _recalcVariantPriceAndStock();
  }

  List<Map<String, dynamic>> _getVariantsList() {
    final raw = _product['variants'];
    if (raw == null) return [];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  void _recalcVariantPriceAndStock() {
    final variants = _getVariantsList();
    double? priceOverride;
    int? stockOverride;

    for (var v in variants) {
      final type = v['type']?.toString() ?? '';
      final selectedOptName = _selectedVariants[type];
      final options = (v['options'] as List?) ?? [];
      for (var opt in options) {
        if (opt is Map) {
          final name = opt['name']?.toString();
          if (name == selectedOptName) {
            if (opt['price_override'] != null) {
              final p = double.tryParse(opt['price_override'].toString());
              if (p != null && p > 0) priceOverride = p;
            }
            if (opt['stock'] != null) {
              final s = int.tryParse(opt['stock'].toString());
              if (s != null) stockOverride = s;
            }
          }
        }
      }
    }

    setState(() {
      _variantPriceOverride = priceOverride;
      _variantStockOverride = stockOverride;
    });
  }

  Future<void> _loadSimilarProducts() async {
    try {
      final categoryId = _product['category_id']?.toString();
      final lang = Get.locale?.languageCode ?? 'en';
      final products = await _productService.getProducts(
        categoryId: categoryId,
        lang: lang,
      );
      if (mounted) {
        setState(() {
          _similarProducts = products.where((p) => p['id'] != _product['id']).toList();
          _loadingSimilar = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSimilar = false);
    }
  }

  Future<void> _checkWishlistStatus() async {
    if (!_authController.isLoggedIn.value) {
      setState(() => _loadingWishlist = false);
      return;
    }
    final wishlist = await _wishlistService.getWishlist();
    final item = wishlist.firstWhereOrNull((element) =>
        element['product_id'] == _product['id'] ||
        element['product']?['id'] == _product['id']);
    if (mounted) {
      setState(() {
        _isWishlisted = item != null;
        _wishlistItemId = item?['id'];
        _loadingWishlist = false;
      });
    }
  }

  Future<void> _toggleWishlist() async {
    if (!_authController.isLoggedIn.value) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() => _loadingWishlist = true);
    if (_isWishlisted && _wishlistItemId != null) {
      final success = await _wishlistService.removeFromWishlist(_wishlistItemId!);
      if (success) {
        AppSnackbar.info(context, 'removed_from_wishlist'.tr(), icon: Icons.favorite_border_rounded);
        _isWishlisted = false;
        _wishlistItemId = null;
      }
    } else {
      final images = _product['images'] as List? ?? [];
      final imageUrl = images.isNotEmpty ? images[0] : '';
      final res = await _wishlistService.addToWishlist(
        productId: _product['id'],
        title: _product['title'],
        price: '${_product['price']}',
        imageUrl: imageUrl,
        source: 'internal',
      );
      if (res != null) {
        AppSnackbar.success(context, 'added_to_wishlist'.tr());
        _isWishlisted = true;
        _wishlistItemId = res['id'];
      }
    }
    setState(() => _loadingWishlist = false);
  }

  Future<void> _addToCart() async {
    if (!_authController.isLoggedIn.value) {
      final loginRes = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (loginRes != true) return;
    }

    final images = _product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : '';
    final finalPrice = _variantPriceOverride ??
        (_product['discount_price'] ?? _product['price']);

    final result = await _cartController.addToCart(
      cartType: 'internal',
      productId: _product['id'],
      title: _product['title'],
      price: '$finalPrice',
      imageUrl: imageUrl,
      selectionsJson: _selectedVariants.isNotEmpty ? jsonEncode(_selectedVariants) : null,
    );

    if (result == AddToCartStatus.success) {
      AppSnackbar.success(context, 'added_to_cart'.tr());
    } else {
      AppSnackbar.error(context, 'failed_to_add_cart'.tr());
    }
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.trim().isEmpty) return null;
    final clean = colorStr.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final hex = int.tryParse('FF$clean', radix: 16);
      if (hex != null) return Color(hex);
    } else if (clean.length == 8) {
      final hex = int.tryParse(clean, radix: 16);
      if (hex != null) return Color(hex);
    }
    final lower = colorStr.toLowerCase().trim();
    const map = {
      'red': Colors.red,
      'احمر': Colors.red,
      'أحمر': Colors.red,
      'black': Colors.black,
      'اسود': Colors.black,
      'أسود': Colors.black,
      'white': Colors.white,
      'ابيض': Colors.white,
      'أبيض': Colors.white,
      'blue': Colors.blue,
      'ازرق': Colors.blue,
      'أزرق': Colors.blue,
      'green': Colors.green,
      'اخضر': Colors.green,
      'أخضر': Colors.green,
      'brown': Color(0xFF795548),
      'بني': Color(0xFF795548),
      'grey': Colors.grey,
      'gray': Colors.grey,
      'رمادي': Color(0xFF616161),
      'charcoal': Color(0xFF424242),
      'yellow': Colors.yellow,
      'اصفر': Colors.yellow,
      'أصفر': Colors.yellow,
      'pink': Colors.pink,
      'وردي': Colors.pink,
      'beige': Color(0xFFF5F5DC),
      'بيج': Color(0xFFF5F5DC),
      'navy': Color(0xFF000080),
      'كحلي': Color(0xFF000080),
    };
    return map[lower];
  }

  @override
  Widget build(BuildContext context) {
    final images = _product['images'] as List? ?? [];
    final hasDiscount = _product['discount_price'] != null;
    final double originalPrice = (_product['price'] ?? 0.0).toDouble();
    final double originalDiscount = hasDiscount ? (_product['discount_price'] ?? 0.0).toDouble() : 0.0;
    final originalCurrency = _product['currency'] ?? 'SAR';

    final effectivePrice = _variantPriceOverride ?? (hasDiscount ? originalDiscount : originalPrice);
    final effectiveStock = _variantStockOverride ?? (_product['stock'] ?? 0);
    final isArabic = (Get.locale?.languageCode ?? 'en') == 'ar';

    final variants = _getVariantsList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Product Image Carousel
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: images[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => Container(color: AppColors.surfaceVariant),
                              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40)),
                            );
                          },
                        ),
                        // Dots Indicator
                        if (images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                images.length,
                                (index) => Container(
                                  width: _currentImageIndex == index ? 24 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: _currentImageIndex == index ? AppColors.primary : Colors.white70,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Center(child: Icon(Icons.image, size: 60, color: AppColors.textHint)),
                    ),
            ),
            actions: [
              // Compare Button
              Obx(() {
                final isInCompare = _compareController.isComparing(_product['id']);
                return IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      size: 20,
                      color: isInCompare ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  tooltip: isInCompare ? 'remove_from_compare'.tr() : 'add_to_compare'.tr(),
                  onPressed: () {
                    _compareController.toggleCompare(_product);
                  },
                );
              }),
              // Wishlist Button
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: _loadingWishlist
                    ? const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : IconButton(
                        icon: Icon(
                          _isWishlisted ? Icons.favorite : Icons.favorite_border,
                          color: _isWishlisted ? AppColors.error : AppColors.textSecondary,
                        ),
                        onPressed: _toggleWishlist,
                      ),
              ),
            ],
          ),

          // Details Layout
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price and Stock status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Obx(() => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _settingsController.formatPrice(effectivePrice, originalCurrency),
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                              if (hasDiscount && _variantPriceOverride == null)
                                Text(
                                  _settingsController.formatPrice(originalPrice, originalCurrency),
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    color: AppColors.textHint,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: effectiveStock > 0
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          effectiveStock > 0 ? 'in_stock'.tr() : 'out_of_stock'.tr(),
                          style: TextStyle(
                            color: effectiveStock > 0 ? AppColors.success : AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Product Title
                  Text(
                    _product['title'] ?? '',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),

                  const SizedBox(height: 12),

                  // Rating Row
                  if (_product['rating'] != null && _product['rating'] > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.warning, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${_product['rating']}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${_product['rating_count'] ?? 0} ${'reviews'.tr()})',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),

                  // ── Dynamic Variants Section (Matches Exact Reference Image 1) ──
                  if (variants.isNotEmpty) ...[
                    const Divider(height: 32),
                    ...variants.map((v) => _buildVariantSelector(v, isArabic)),
                  ],

                  const Divider(height: 32),

                  // Seller Row (if seller exists)
                  if (_product['seller_id'] != null) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerShopScreen(sellerId: _product['seller_id']),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                              child: const Icon(Icons.storefront, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Seller Shop'.tr(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(
                                    _product['seller']?['store_name'] ?? 'Browse Shop'.tr(),
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textHint),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Tabs: Description vs Reviews (Matches Exact Reference Image 2) ──
                  Row(
                    children: [
                      _buildTabItem(
                        title: isArabic ? 'وصف المنتج' : 'Description',
                        index: 0,
                      ),
                      const SizedBox(width: 24),
                      _buildTabItem(
                        title: isArabic ? 'التعليقات' : 'Reviews',
                        index: 1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_selectedTab == 0)
                    _buildDescriptionContent()
                  else
                    _buildReviewsContent(isArabic),

                  // ── Similar Products Section ──
                  const SizedBox(height: 28),
                  _buildSimilarProductsSection(),

                  const SizedBox(height: 120), // Spacing for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: effectiveStock > 0 ? _addToCart : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'add_to_cart'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({required String title, required int index}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFFD81B60) : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD81B60) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSelector(Map<String, dynamic> variant, bool isArabic) {
    final type = variant['type']?.toString() ?? '';
    final options = (variant['options'] as List?) ?? [];
    if (options.isEmpty) return const SizedBox.shrink();

    final isColor = type.toLowerCase().contains('color') || type.contains('اللون') || type.contains('لون');
    final isSize = type.toLowerCase().contains('size') || type.contains('المقاس') || type.contains('مقاس') || type.contains('حجم');
    final selectedOpt = _selectedVariants[type];

    String labelText = type;
    if (isColor) {
      labelText = isArabic ? 'اللون' : 'Color';
    } else if (isSize) {
      labelText = isArabic ? 'المقاس' : 'Size';
    }

    final swatchesOrChips = Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: options.map((opt) {
        final optName = opt is Map ? opt['name']?.toString() ?? '' : opt.toString();
        final isSelected = selectedOpt == optName;
        final colorHex = opt is Map ? (opt['color_hex']?.toString() ?? opt['hex']?.toString()) : null;
        final parsedColor = _parseColor(colorHex ?? optName);

        if (isColor && parsedColor != null) {
          // Circular Color Swatch (Matches user reference image 1)
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedVariants[type] = optName;
                _recalcVariantPriceAndStock();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: parsedColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.black87 : Colors.grey.shade400,
                  width: isSelected ? 2.5 : 1.2,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: parsedColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 20,
                      color: (parsedColor.computeLuminance() > 0.5) ? Colors.black : Colors.white,
                    )
                  : null,
            ),
          );
        }

        // Size / Option Chip (Matches user reference image 1: XL, L, M, S)
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedVariants[type] = optName;
              _recalcVariantPriceAndStock();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 1.8 : 1.2,
              ),
            ),
            child: Text(
              optName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : const Color(0xFF37474F),
              ),
            ),
          ),
        );
      }).toList(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // On Arabic (RTL), align swatches/chips on left and label on right
          if (isArabic) ...[
            Expanded(child: Align(alignment: Alignment.centerLeft, child: swatchesOrChips)),
            const SizedBox(width: 16),
            Text(
              labelText,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ] else ...[
            Text(
              labelText,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(child: Align(alignment: Alignment.centerRight, child: swatchesOrChips)),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionContent() {
    final rawDesc = _product['description'] ?? _product['description_ar'] ?? _product['description_en'] ?? '';
    if (rawDesc.isEmpty) {
      return Text(
        'No description available.'.tr(),
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
      );
    }

    final hasHtmlTags = rawDesc.contains('<') && rawDesc.contains('>');
    if (hasHtmlTags) {
      return HtmlWidget(
        rawDesc,
        textStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.6),
        customStylesBuilder: (element) {
          if (element.localName == 'table') {
            return {
              'border-collapse': 'collapse',
              'width': '100%',
              'margin': '12px 0',
              'border': '1px solid #D1D5DB',
            };
          }
          if (element.localName == 'th' || element.localName == 'td') {
            return {
              'border': '1px solid #D1D5DB',
              'padding': '8px 10px',
              'text-align': 'center',
            };
          }
          if (element.localName == 'th') {
            return {
              'background-color': '#F8F9FA',
              'font-weight': 'bold',
            };
          }
          return null;
        },
      );
    }

    return Text(
      rawDesc,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
    );
  }

  Widget _buildReviewsContent(bool isArabic) {
    final rating = (_product['rating'] ?? 5.0).toDouble();
    final count = _product['rating_count'] ?? 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating.floor() ? Icons.star : Icons.star_border,
                        color: AppColors.warning,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count ${isArabic ? "تقييم من المشترين" : "customer ratings"}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSingleReview(
          name: isArabic ? 'سارة العتيبي' : 'Sarah A.',
          date: isArabic ? 'منذ يومين' : '2 days ago',
          rating: 5,
          comment: isArabic
              ? 'العباءة فخمة جداً والقماش رائع وبارد، التوصيل تم خلال أقل من 24 ساعة كما هو موضح!'
              : 'The abaya is luxurious and fabric is light. Delivery was within 24 hours as promised!',
        ),
        const SizedBox(height: 10),
        _buildSingleReview(
          name: isArabic ? 'نورة محمد' : 'Noura M.',
          date: isArabic ? 'منذ أسبوع' : '1 week ago',
          rating: 5,
          comment: isArabic
              ? 'المقاس مضبوط تماماً وجودة الخياطة ممتازة. أنصح بالشراء.'
              : 'The size is very accurate and stitching quality is excellent. Highly recommended.',
        ),
      ],
    );
  }

  Widget _buildSingleReview({
    required String name,
    required String date,
    required int rating,
    required String comment,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(date, style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                color: AppColors.warning,
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(comment, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSimilarProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              (Get.locale?.languageCode ?? 'en') == 'ar' ? 'منتجات مشابهة' : 'Similar Products',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loadingSimilar)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          )
        else if (_similarProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            child: Text(
              (Get.locale?.languageCode ?? 'en') == 'ar' ? 'لا توجد منتجات مشابهة' : 'No similar products found',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _similarProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final p = _similarProducts[index];
                final pImages = p['images'] as List? ?? [];
                final pImg = pImages.isNotEmpty ? pImages[0] : null;
                final pPrice = (p['price'] ?? 0.0).toDouble();
                final pCurr = p['currency'] ?? 'SAR';

                return GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                    );
                  },
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider, width: 0.6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            child: pImg != null
                                ? CachedNetworkImage(imageUrl: pImg, fit: BoxFit.cover, width: double.infinity)
                                : Container(color: AppColors.surfaceVariant),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['title'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const Spacer(),
                                Text(
                                  _settingsController.formatPrice(pPrice, pCurr),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
