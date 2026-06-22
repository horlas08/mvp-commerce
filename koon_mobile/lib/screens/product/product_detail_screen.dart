import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/compare_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../services/wishlist_service.dart';
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

  int _currentImageIndex = 0;
  bool _isWishlisted = false;
  String? _wishlistItemId;
  bool _loadingWishlist = true;

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
  }

  Future<void> _checkWishlistStatus() async {
    if (!_authController.isLoggedIn.value) {
      setState(() => _loadingWishlist = false);
      return;
    }
    final wishlist = await _wishlistService.getWishlist();
    final item = wishlist.firstWhereOrNull((element) =>
        element['product_id'] == widget.product['id'] ||
        element['product']?['id'] == widget.product['id']);
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
        Get.snackbar('Wishlist', 'Removed from Wishlist'.tr(), snackPosition: SnackPosition.BOTTOM);
        _isWishlisted = false;
        _wishlistItemId = null;
      }
    } else {
      final images = widget.product['images'] as List? ?? [];
      final imageUrl = images.isNotEmpty ? images[0] : '';
      final res = await _wishlistService.addToWishlist(
        productId: widget.product['id'],
        title: widget.product['title'],
        price: '${widget.product['price']}',
        imageUrl: imageUrl,
        source: 'internal',
      );
      if (res != null) {
        Get.snackbar('Wishlist', 'Added to Wishlist'.tr(), snackPosition: SnackPosition.BOTTOM);
        _isWishlisted = true;
        _wishlistItemId = res['id'];
      }
    }
    setState(() => _loadingWishlist = false);
  }

  Future<void> _addToCart() async {
    if (!_authController.isLoggedIn.value) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final images = widget.product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : '';
    final success = await _cartController.addToCart(
      cartType: 'internal',
      productId: widget.product['id'],
      title: widget.product['title'],
      price: '${widget.product['price']}',
      imageUrl: imageUrl,
    );

    if (success) {
      Get.snackbar(
        'Cart',
        'Added to your cart!'.tr(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product['images'] as List? ?? [];
    final hasDiscount = widget.product['discount_price'] != null;
    final double originalPrice = (widget.product['price'] ?? 0.0).toDouble();
    final double originalDiscount = hasDiscount ? (widget.product['discount_price'] ?? 0.0).toDouble() : 0.0;
    final originalCurrency = widget.product['currency'] ?? 'SAR';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Elegant Header with Back Button and Wishlist Action
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => Container(color: AppColors.surfaceVariant),
                          errorWidget: (_, __, ___) => Container(color: AppColors.surfaceVariant, child: const Icon(Icons.image, size: 60)),
                        );
                      },
                    )
                  else
                    Container(color: AppColors.surfaceVariant, child: const Icon(Icons.image, size: 80)),

                  // Gradient overlay on image
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                        ),
                      ),
                    ),
                  ),

                  // Carousel Indicators
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _currentImageIndex == index ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index ? AppColors.primary : Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              // Compare Toggle Button
              Obx(() {
                final isComparing = _compareController.isComparing(widget.product['id']);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(Icons.compare_arrows, color: isComparing ? AppColors.primary : AppColors.textSecondary),
                    onPressed: () => _compareController.toggleCompare(widget.product),
                  ),
                );
              }),

              // Wishlist Toggle Button
              Container(
                margin: const EdgeInsets.only(right: 16, left: 4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: _loadingWishlist
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
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
                                _settingsController.formatPrice(
                                    hasDiscount ? originalDiscount : originalPrice,
                                    originalCurrency),
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                              if (hasDiscount)
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
                          color: (widget.product['stock'] ?? 0) > 0
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (widget.product['stock'] ?? 0) > 0 ? 'in_stock'.tr() : 'out_of_stock'.tr(),
                          style: TextStyle(
                            color: (widget.product['stock'] ?? 0) > 0 ? AppColors.success : AppColors.error,
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
                    widget.product['title'] ?? '',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),

                  const SizedBox(height: 12),

                  // Rating Row
                  if (widget.product['rating'] != null && widget.product['rating'] > 0)
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.warning, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.product['rating']}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${widget.product['rating_count'] ?? 0} ${'reviews'.tr()})',
                          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),

                  const Divider(height: 32),

                  // Seller Row (if seller exists)
                  if (widget.product['seller_id'] != null) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerShopScreen(sellerId: widget.product['seller_id']),
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
                                    widget.product['seller']?['store_name'] ?? 'Browse Shop'.tr(),
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

                  // Description
                  Text(
                    'description'.tr(),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product['description'] ?? widget.product['description_en'] ?? 'No description available.'.tr(),
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),

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
            onPressed: (widget.product['stock'] ?? 0) > 0 ? _addToCart : null,
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
}
