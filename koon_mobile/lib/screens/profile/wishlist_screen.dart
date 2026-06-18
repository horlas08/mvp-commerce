import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../services/wishlist_service.dart';
import '../../services/cart_service.dart';
import '../../controllers/settings_controller.dart';
import '../product/product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistService _wishlistService = WishlistService();
  final CartService _cartService = CartService();
  final SettingsController _settingsController = Get.find<SettingsController>();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    setState(() => _isLoading = true);
    final lang = context.locale.languageCode;
    final data = await _wishlistService.getWishlist(lang: lang);
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  Future<void> _removeItem(String id) async {
    final success = await _wishlistService.removeFromWishlist(id);
    if (success) {
      _loadWishlist();
    }
  }

  Future<void> _addToCart(Map<String, dynamic> item) async {
    final source = item['source'] ?? 'internal';
    final success = await _cartService.addToCart(
      cartType: source,
      productId: item['product_id'],
      title: item['title'],
      price: item['price'],
      imageUrl: item['image_url'],
      externalUrl: item['external_url'],
      siteName: source == 'internal' ? 'Internal' : source,
    );
    if (success != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('added_to_cart'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_wishlist'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_border_outlined, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('your_wishlist_is_empty'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final title = item['title'] ?? item['product']?['title'] ?? 'Product';
                    final imageUrl = item['image_url'] ?? (item['product']?['images'] as List?)?.firstOrNull?.toString();
                    
                    final double priceVal = (item['product']?['price'] ?? double.tryParse(item['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0).toDouble();
                    final String originalCurrency = item['product']?['currency'] ?? 'SAR';

                    // Prepare productMap to navigate to detail screen
                    final Map<String, dynamic> productMap = Map<String, dynamic>.from(item['product'] ?? item);
                    productMap['id'] ??= item['product_id'];
                    productMap['title'] ??= title;
                    productMap['price'] ??= priceVal;
                    productMap['currency'] ??= originalCurrency;
                    if (imageUrl != null) {
                      productMap['images'] ??= [imageUrl];
                    }

                    return Obx(() => GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: productMap),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider, width: 0.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: imageUrl != null
                                            ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                            : Container(color: AppColors.surfaceVariant, child: const Center(child: Icon(Icons.image, size: 40, color: AppColors.textHint))),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: GestureDetector(
                                          onTap: () => _removeItem(item['id']),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(Icons.favorite, color: AppColors.error, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                                        const Spacer(),
                                        Text(
                                          _settingsController.formatPrice(priceVal, originalCurrency),
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 30,
                                          child: ElevatedButton(
                                            onPressed: () => _addToCart(item),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.secondary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: Text('add_to_cart'.tr(), style: const TextStyle(fontSize: 11, color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ));
                  },
                ),
    );
  }
}
