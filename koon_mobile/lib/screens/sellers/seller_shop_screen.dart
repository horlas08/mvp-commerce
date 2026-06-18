import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../controllers/settings_controller.dart';
import '../product/product_detail_screen.dart';

class SellerShopScreen extends StatefulWidget {
  final String sellerId;

  const SellerShopScreen({super.key, required this.sellerId});

  @override
  State<SellerShopScreen> createState() => _SellerShopScreenState();
}

class _SellerShopScreenState extends State<SellerShopScreen> {
  final SettingsController _settingsController = Get.find<SettingsController>();
  Map<String, dynamic>? _sellerInfo;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final lang = context.locale.languageCode;
    final dio = ApiService().dio;

    try {
      // Fetch Seller Info
      final infoRes = await dio.get('/sellers/${widget.sellerId}', queryParameters: {'lang': lang});
      if (infoRes.statusCode == 200) {
        _sellerInfo = Map<String, dynamic>.from(infoRes.data);
      }

      // Fetch Seller Products
      final productsRes = await dio.get('/products', queryParameters: {'seller_id': widget.sellerId, 'lang': lang});
      if (productsRes.statusCode == 200) {
        _products = List<Map<String, dynamic>>.from(productsRes.data);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_sellerInfo?['store_name'] ?? 'Seller Shop'.tr()),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Seller Header Info Card
                if (_sellerInfo != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primarySurface,
                          backgroundImage: _sellerInfo!['logo_url'] != null
                              ? NetworkImage(_sellerInfo!['logo_url'])
                              : null,
                          child: _sellerInfo!['logo_url'] == null
                              ? const Icon(Icons.storefront, size: 32, color: AppColors.primary)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sellerInfo!['store_name'] ?? '',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sellerInfo!['description'] ?? 'No description available.'.tr(),
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                // Products Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'Products'.tr(),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                ),

                // Shop Products Grid
                Expanded(
                  child: _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 16),
                              Text('No products listed by this seller'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
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
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return _buildProductCard(product);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final images = product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;
    final hasDiscount = product['discount_price'] != null;
    final double originalPrice = (product['price'] ?? 0.0).toDouble();
    final double originalDiscount = hasDiscount ? (product['discount_price'] ?? 0.0).toDouble() : 0.0;
    final originalCurrency = product['currency'] ?? 'SAR';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imageUrl != null
                    ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        color: AppColors.surfaceVariant,
                        child: const Center(child: Icon(Icons.image, size: 40, color: AppColors.textHint)),
                      ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          _settingsController.formatPrice(
                              hasDiscount ? originalDiscount : originalPrice,
                              originalCurrency),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                    if (hasDiscount)
                      Text(
                        _settingsController.formatPrice(originalPrice, originalCurrency),
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint, decoration: TextDecoration.lineThrough),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}
