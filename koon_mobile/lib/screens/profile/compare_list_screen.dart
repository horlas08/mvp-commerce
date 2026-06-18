import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/compare_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_screen.dart';

class CompareListScreen extends StatelessWidget {
  const CompareListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compareController = Get.find<CompareController>();
    final settingsController = Get.find<SettingsController>();
    final cartController = Get.find<CartController>();
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('compare_list'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          Obx(() {
            if (compareController.comparedProducts.isEmpty) return const SizedBox.shrink();
            return TextButton(
              onPressed: () => compareController.clearCompareList(),
              child: Text(
                'Clear All'.tr(),
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        final products = compareController.comparedProducts;

        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.compare_arrows_outlined, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    'No products to compare'.tr(),
                    style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add products from detail screens to start comparing specs and prices.'.tr(),
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Labels Column
                _buildLabelsColumn(),

                // Product Columns
                ...products.map((product) => _buildProductColumn(
                      context,
                      product,
                      settingsController,
                      compareController,
                      cartController,
                      authController,
                    )),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLabelsColumn() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(left: 16, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 140), // Spacing aligned with product image
          _buildLabelCell('Price'.tr()),
          _buildLabelCell('Rating'.tr()),
          _buildLabelCell('Stock'.tr()),
          _buildLabelCell('Description'.tr(), height: 120),
        ],
      ),
    );
  }

  Widget _buildLabelCell(String text, {double height = 48}) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildProductColumn(
    BuildContext context,
    Map<String, dynamic> product,
    SettingsController settingsController,
    CompareController compareController,
    CartController cartController,
    AuthController authController,
  ) {
    final images = product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images[0] : null;
    final hasDiscount = product['discount_price'] != null;
    final double price = (product['price'] ?? 0.0).toDouble();
    final double discount = hasDiscount ? (product['discount_price'] ?? 0.0).toDouble() : 0.0;
    final currency = product['currency'] ?? 'SAR';

    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          // Close button & Image
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: double.infinity,
                          height: 120,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.image, color: AppColors.textHint),
                        ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => compareController.toggleCompare(product),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 16, color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              product['title'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          // Price Cell
          _buildValueCell(
            Text(
              settingsController.formatPrice(hasDiscount ? discount : price, currency),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
            ),
          ),

          // Rating Cell
          _buildValueCell(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppColors.warning, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${product['rating'] ?? 0.0}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),

          // Stock Cell
          _buildValueCell(
            Text(
              (product['stock'] ?? 0) > 0 ? 'in_stock'.tr() : 'out_of_stock'.tr(),
              style: TextStyle(
                color: (product['stock'] ?? 0) > 0 ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),

          // Description Cell
          _buildValueCell(
            SingleChildScrollView(
              child: Text(
                product['description'] ?? product['description_en'] ?? 'No description available.'.tr(),
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                textAlign: TextAlign.center,
              ),
            ),
            height: 120,
          ),

          // Action Cell
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: (product['stock'] ?? 0) > 0
                    ? () async {
                        if (!authController.isLoggedIn.value) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                          return;
                        }
                        final success = await cartController.addToCart(
                          cartType: 'internal',
                          productId: product['id'],
                          title: product['title'],
                          price: '${product['price']}',
                          imageUrl: imageUrl ?? '',
                        );
                        if (success) {
                          Get.snackbar('Cart', 'Added to your cart!'.tr(), snackPosition: SnackPosition.BOTTOM);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Add to Cart'.tr(), style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCell(Widget child, {double height = 48}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: child,
    );
  }
}
