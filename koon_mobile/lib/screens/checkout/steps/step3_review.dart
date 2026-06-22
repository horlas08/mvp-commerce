import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/theme/app_colors.dart';
import '../../../controllers/checkout_controller.dart';
import '../../../controllers/settings_controller.dart';

class Step3Review extends StatelessWidget {
  const Step3Review({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CheckoutController>();
    final settings = Get.find<SettingsController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_summary'.tr(),
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // ── Cart Items ─────────────────────────────────────────────────
          ...ctrl.cartItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final title =
                item['title'] ?? item['product']?['title'] ?? 'Product';
            final double price = (item['product']?['price'] ??
                    double.tryParse(
                          item['price']?.toString().replaceAll(
                                    RegExp(r'[^0-9.]'),
                                    '',
                                  ) ??
                              '0',
                        ) ??
                    0.0)
                .toDouble();
            final imageUrl = item['image_url'] ??
                (item['product']?['images'] as List?)
                    ?.firstOrNull
                    ?.toString();
            final qty = item['quantity'] ?? 1;
            final currency =
                item['product']?['currency'] ?? 'SAR';

            return _ReviewItemCard(
              title: title,
              price: settings.formatPrice(price, currency),
              imageUrl: imageUrl,
              quantity: qty,
            )
                .animate(delay: Duration(milliseconds: index * 60))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.04);
          }),

          const SizedBox(height: 16),

          // ── Address Summary ────────────────────────────────────────────
          Obx(() {
            final addr = ctrl.selectedAddress.value;
            if (addr == null) return const SizedBox();
            return _SummaryCard(
              title: 'delivery_to'.tr(),
              icon: Icons.location_on_outlined,
              iconColor: AppColors.primary,
              child: Text(
                '${addr['label'] ?? ''} · ${addr['street'] ?? ''}, ${addr['city'] ?? ''}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 300.ms);
          }),
          const SizedBox(height: 10),

          // ── Shipping Summary ───────────────────────────────────────────
          Obx(() {
            String shippingLabel;
            if (ctrl.cartType == 'internal') {
              if (ctrl.shippingType.value == 'pickup' &&
                  ctrl.selectedPickupStation.value != null) {
                shippingLabel =
                    '${ctrl.selectedPickupStation.value!['name']}';
              } else {
                shippingLabel = ctrl.shippingType.value == 'home'
                    ? 'home_delivery'.tr()
                    : 'pickup'.tr();
              }
            } else {
              shippingLabel = ctrl.allowTeamReview.value
                  ? 'team_review'.tr()
                  : 'standard_processing'.tr();
            }
            return _SummaryCard(
              title: 'shipping_method'.tr(),
              icon: Icons.local_shipping_outlined,
              iconColor: AppColors.secondary,
              child: Text(
                shippingLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ).animate(delay: 140.ms).fadeIn(duration: 300.ms);
          }),
          const SizedBox(height: 10),

          // ── Note ───────────────────────────────────────────────────────
          Obx(() {
            final note = ctrl.additionalNote.value;
            if (note.isEmpty) return const SizedBox();
            return _SummaryCard(
              title: 'additional_note'.tr(),
              icon: Icons.notes_outlined,
              iconColor: AppColors.textSecondary,
              child: Text(
                note,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ).animate(delay: 160.ms).fadeIn(duration: 300.ms);
          }),
          const SizedBox(height: 16),

          // ── Price Breakdown ────────────────────────────────────────────
          Obx(() => _PriceBreakdown(ctrl: ctrl, settings: settings))
              .animate(delay: 200.ms)
              .fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  final String title;
  final String price;
  final String? imageUrl;
  final int quantity;

  const _ReviewItemCard({
    required this.title,
    required this.price,
    this.imageUrl,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.image, color: AppColors.textHint),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'x$quantity',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                    Text(
                      price,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceBreakdown extends StatelessWidget {
  final CheckoutController ctrl;
  final SettingsController settings;

  const _PriceBreakdown({required this.ctrl, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1565C0),
            Color(0xFF42A5F5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _priceRow('subtotal'.tr(), settings.formatPrice(ctrl.subtotal, 'SAR'),
              Colors.white70),
          if (ctrl.shippingFee > 0)
            _priceRow(
              'shipping_fee'.tr(),
              settings.formatPrice(ctrl.shippingFee, 'SAR'),
              Colors.white70,
            ),
          if (ctrl.teamReviewFee > 0)
            _priceRow(
              'service_fee'.tr(),
              settings.formatPrice(ctrl.teamReviewFee, 'SAR'),
              Colors.white70,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _priceRow(
            'order_total'.tr(),
            settings.formatPrice(ctrl.orderTotal, 'SAR'),
            Colors.white,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, Color color,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 18 : 13,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
