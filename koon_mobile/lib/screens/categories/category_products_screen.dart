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

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final SettingsController _settingsController = Get.find<SettingsController>();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final lang = context.locale.languageCode;
    final dio = ApiService().dio;

    try {
      final res = await dio.get('/products', queryParameters: {
        'category_id': widget.categoryId,
        'lang': lang,
      });
      if (res.statusCode == 200) {
        _products = List<Map<String, dynamic>>.from(res.data);
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
        title: Text(widget.categoryName),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.category_outlined, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('No products in this category'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
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
