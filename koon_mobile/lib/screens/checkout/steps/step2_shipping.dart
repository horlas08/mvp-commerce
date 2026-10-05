import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../controllers/checkout_controller.dart';
import '../../../controllers/settings_controller.dart';

class Step2Shipping extends StatefulWidget {
  const Step2Shipping({super.key});

  @override
  State<Step2Shipping> createState() => _Step2ShippingState();
}

class _Step2ShippingState extends State<Step2Shipping> {
  bool _showNote = false;

  @override
  void initState() {
    super.initState();
    final ctrl = Get.find<CheckoutController>();
    _showNote = ctrl.additionalNote.value.trim().isNotEmpty;
  }

  bool get isExternalCart {
    final ctrl = Get.find<CheckoutController>();
    return ctrl.cartType != 'internal';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CheckoutController>();
    final settings = Get.find<SettingsController>();
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
            _TeamReviewCard(ctrl: ctrl)
                .animate()
                .fadeIn(duration: 300.ms)
                .slideX(begin: -0.04),
            const SizedBox(height: 16),
          ],

          // ── Additional note (both cart types) ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'additional_note'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showNote = !_showNote;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    _showNote ? 'hide_note'.tr() : 'add_note'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
          if (_showNote) ...[
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
            ).animate().fadeIn(duration: 200.ms),
          ],
          const SizedBox(height: 24),
          _PriceBreakdown(ctrl: ctrl, settings: settings)
              .animate(delay: 140.ms)
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 16),
          _CouponInputSection(ctrl: ctrl, settings: settings)
              .animate(delay: 160.ms)
              .fadeIn(duration: 300.ms),
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
    final settings = Get.find<SettingsController>();
    return Obx(() => Container(
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
                Switch(
                  value: ctrl.allowTeamReview.value,
                  onChanged: (v) => ctrl.allowTeamReview.value = v,
                  activeColor: AppColors.secondary,
                ),
              ],
            ),
            // Fee badge when enabled
            if (ctrl.allowTeamReview.value)
              Padding(
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
                        '${'review_fee'.tr()}: ${settings.formatPrice(ctrl.teamReviewPrice, 'SAR')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2),
          ],
        ),
      ),
    ));
  }
}

class _PriceBreakdown extends StatelessWidget {
  final CheckoutController ctrl;
  final SettingsController settings;

  const _PriceBreakdown({required this.ctrl, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shippingDisplay = ctrl.shippingFee > 0
          ? settings.formatPrice(ctrl.shippingFee, 'SAR')
          : 'free'.tr();
      final commissionDisplay = ctrl.commissionFee > 0
          ? settings.formatPrice(ctrl.commissionFee, 'SAR')
          : settings.formatPrice(0.0, 'SAR');
      final discountDisplay = ctrl.discount > 0
          ? '-${settings.formatPrice(ctrl.discount, 'SAR')}'
          : settings.formatPrice(0.0, 'SAR');
      final taxLabel = ctrl.taxPercentage.value > 0
          ? '${'tax'.tr()} (${ctrl.taxPercentage.value.toStringAsFixed(ctrl.taxPercentage.value.truncateToDouble() == ctrl.taxPercentage.value ? 0 : 1)}%)'
          : 'tax'.tr();
      final taxDisplay = settings.formatPrice(ctrl.tax, 'SAR');

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.secondaryGradient,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            if (ctrl.discount > 0)
              _priceRow(
                'discount'.tr(),
                discountDisplay,
                const Color(0xFF4ADE80),
                valueColor: const Color(0xFF4ADE80),
              ),
            _priceRow(
              'shipping_cost'.tr(),
              shippingDisplay,
              Colors.white70,
            ),
            _priceRow(
              'commission_fee'.tr(),
              commissionDisplay,
              Colors.white70,
            ),
            if (ctrl.allowTeamReview.value)
              _priceRow(
                'team_review'.tr(),
                settings.formatPrice(ctrl.teamReviewFee, 'SAR'),
                Colors.white70,
              ),
            _priceRow(
              taxLabel,
              taxDisplay,
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
    });
  }

  Widget _priceRow(
    String label,
    String value,
    Color color, {
    Color? valueColor,
    bool isTotal = false,
  }) {
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
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponInputSection extends StatefulWidget {
  final CheckoutController ctrl;
  final SettingsController settings;

  const _CouponInputSection({required this.ctrl, required this.settings});

  @override
  State<_CouponInputSection> createState() => _CouponInputSectionState();
}

class _CouponInputSectionState extends State<_CouponInputSection> {
  final TextEditingController _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isApplied = widget.ctrl.couponCode.value.isNotEmpty;

      if (isApplied) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.ctrl.couponCode.value,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'coupon_applied'.tr(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '-${widget.settings.formatPrice(widget.ctrl.discount, 'SAR')}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                tooltip: 'remove'.tr(),
                onPressed: () {
                  _textCtrl.clear();
                  widget.ctrl.removeCoupon();
                },
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _textCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'enter_coupon_code'.tr(),
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textHint,
                    ),
                    prefixIcon: const Icon(
                      Icons.discount_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
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
                      borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.ctrl.isApplyingCoupon.value
                      ? null
                      : () => widget.ctrl.applyCoupon(_textCtrl.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    elevation: 0,
                  ),
                  child: widget.ctrl.isApplyingCoupon.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'apply'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (widget.ctrl.couponError.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
              child: Text(
                widget.ctrl.couponError.value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      );
    });
  }
}
