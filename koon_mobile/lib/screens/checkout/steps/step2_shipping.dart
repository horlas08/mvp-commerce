import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../controllers/checkout_controller.dart';

class Step2Shipping extends StatelessWidget {
  const Step2Shipping({super.key});

  bool get isExternalCart {
    final ctrl = Get.find<CheckoutController>();
    return ctrl.cartType != 'internal';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CheckoutController>();
    final isExternal = ctrl.cartType != 'internal';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'select_shipping_method'.tr(),
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          if (!isExternal) ...[
            // ── Internal cart: Home Delivery / Pickup ─────────────────
            Obx(() => _ShippingOptionCard(
                  icon: Icons.home_outlined,
                  title: 'home_delivery'.tr(),
                  subtitle: 'home_delivery_subtitle'.tr(),
                  isSelected: ctrl.shippingType.value == 'home',
                  onTap: () => ctrl.shippingType.value = 'home',
                  color: AppColors.secondary,
                )).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04),
            const SizedBox(height: 12),
            Obx(() => _ShippingOptionCard(
                  icon: Icons.storefront_outlined,
                  title: 'pickup'.tr(),
                  subtitle: 'pickup_subtitle'.tr(),
                  isSelected: ctrl.shippingType.value == 'pickup',
                  onTap: () => ctrl.shippingType.value = 'pickup',
                  color: AppColors.primary,
                )).animate(delay: 60.ms).fadeIn(duration: 300.ms).slideX(begin: -0.04),
            const SizedBox(height: 16),

            // Pickup station dropdown (only when pickup selected)
            Obx(() {
              if (ctrl.shippingType.value != 'pickup') return const SizedBox();
              if (ctrl.isLoadingShipping.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(color: AppColors.primary),
                );
              }
              if (ctrl.pickupStations.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'no_pickup_stations'.tr(),
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'pickup_station'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: ctrl.selectedPickupStation.value,
                        isExpanded: true,
                        hint: Text(
                          'pickup_station'.tr(),
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary,
                        ),
                        items: ctrl.pickupStations.map((station) {
                          return DropdownMenuItem(
                            value: station,
                            child: Text(
                              station['name'] ?? '',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            ctrl.selectedPickupStation.value = v,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ).animate().fadeIn(duration: 300.ms);
            }),
          ] else ...[
            // ── External cart: Team Review toggle ─────────────────────
            Obx(() => _TeamReviewCard(ctrl: ctrl))
                .animate()
                .fadeIn(duration: 300.ms)
                .slideX(begin: -0.04),
            const SizedBox(height: 16),
          ],

          // ── Additional note (both cart types) ─────────────────────────
          Text(
            'additional_note'.tr(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: ctrl.additionalNote.value,
            onChanged: (v) => ctrl.additionalNote.value = v,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'additional_note_hint'.tr(),
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.all(16),
            ),
          ).animate(delay: 120.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

class _ShippingOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ShippingOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.divider,
            width: isSelected ? 2 : 1.5,
          ),
          color: isSelected ? color.withOpacity(0.06) : AppColors.surface,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamReviewCard extends StatelessWidget {
  final CheckoutController ctrl;
  const _TeamReviewCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.06),
            AppColors.secondaryLight.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: ctrl.allowTeamReview.value
              ? AppColors.secondary
              : AppColors.divider,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'team_review'.tr(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'team_review_desc'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(() => Switch(
                      value: ctrl.allowTeamReview.value,
                      onChanged: (v) => ctrl.allowTeamReview.value = v,
                      activeColor: AppColors.secondary,
                    )),
              ],
            ),
            // Fee badge when enabled
            Obx(() {
              if (!ctrl.allowTeamReview.value) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${'review_fee'.tr()}: ${'team_review_fee_label'.tr()}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2);
            }),
          ],
        ),
      ),
    );
  }
}
