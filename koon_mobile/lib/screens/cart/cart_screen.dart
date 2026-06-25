import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../auth/login_screen.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends StatelessWidget {
  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    final authController = Get.find<AuthController>();
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('cart'.tr()),
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                tooltip: 'back'.tr(),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          Obx(() => cartController.cartItems.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => cartController.clearCurrentCart(),
                )
              : const SizedBox()),
        ],
      ),
      body: Obx(() {
        if (!authController.isLoggedIn.value) {
          return _buildLoginPrompt(context);
        }

        return Column(
          children: [
            // Cart Type Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: Obx(() => DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: cartController.selectedCartType.value,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                        items: cartController.cartTypes.map((type) {
                          final label = lang == 'ar' ? type['label_ar']! : type['label_en']!;
                          return DropdownMenuItem(value: type['key'], child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) cartController.selectedCartType.value = value;
                        },
                      ),
                    )),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Cart Items
            Expanded(
              child: Obx(() {
                if (cartController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (cartController.cartItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textHint)
                            .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        Text('your_cart_is_empty'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('start_shopping'.tr(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: cartController.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartController.cartItems[index];
                    return _buildCartItem(item, cartController, index);
                  },
                );
              }),
            ),

            // Bottom checkout bar
            Obx(() {
              if (cartController.cartItems.isEmpty) return const SizedBox();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('total_amount'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 2),
                          Obx(() => Text(
                                Get.find<SettingsController>().formatPrice(cartController.totalAmount, 'SAR'),
                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              )),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CheckoutScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('proceed_to_checkout'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut);
            }),
          ],
        );
      }),
      // WhatsApp FAB
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: const Color(0xFF25D366),
        onPressed: () {},
        child: const Icon(Icons.chat, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, CartController controller, int index) {
    final title = item['title'] ?? item['product']?['title'] ?? 'Product';
    final double priceVal = (item['product']?['price'] ?? double.tryParse(item['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0).toDouble();
    final originalCurrency = item['product']?['currency'] ?? 'SAR';
    final imageUrl = item['image_url'] ?? (item['product']?['images'] as List?)?.firstOrNull?.toString();
    final quantity = item['quantity'] ?? 1;
    final settingsController = Get.find<SettingsController>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: item['is_selected'] ?? true,
              onChanged: (v) => controller.toggleSelection(item['id'], v ?? true),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null
                  ? CachedNetworkImage(imageUrl: imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                  : Container(width: 80, height: 80, color: AppColors.surfaceVariant, child: const Icon(Icons.image, color: AppColors.textHint)),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Obx(() => Text(
                        settingsController.formatPrice(priceVal, originalCurrency),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.secondary),
                      )),
                ],
              ),
            ),
            // Quantity controls
            Column(
              children: [
                _buildQtyButton(Icons.add, () => controller.updateQuantity(item['id'], quantity + 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('$quantity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                _buildQtyButton(Icons.remove, () => controller.updateQuantity(item['id'], quantity - 1)),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 300.ms).slideX(begin: 0.05);
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('login_to_continue'.tr(), style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text('login'.tr()),
          ),
        ],
      ),
    );
  }
}
