import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/checkout_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/settings_controller.dart';
import 'steps/step1_address.dart';
import 'steps/step2_shipping.dart';
import 'steps/step3_review.dart';
import 'steps/step4_payment.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final CheckoutController _ctrl;

  @override
  void initState() {
    super.initState();
    final cartCtrl = Get.find<CartController>();

    _ctrl = Get.put(CheckoutController());
    _ctrl.cartType = cartCtrl.selectedCartType.value;
    _ctrl.cartItems = List<Map<String, dynamic>>.from(cartCtrl.cartItems);
    _ctrl.subtotal = cartCtrl.totalAmount;
  }

  static const List<String> _stepKeys = [
    'step_address',
    'step_shipping',
    'step_review',
    'step_payment',
  ];

  static const List<IconData> _stepIcons = [
    Icons.location_on_outlined,
    Icons.local_shipping_outlined,
    Icons.receipt_long_outlined,
    Icons.payment_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'checkout'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
        leading: Obx(() {
          if (_ctrl.orderPlaced.value) return const SizedBox();
          return IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _ctrl.currentStep.value == 0
                ? () => Navigator.of(context).maybePop()
                : _ctrl.prevStep,
          );
        }),
        elevation: 0,
      ),
      body: Obx(() {
        // Order placed success state
        if (_ctrl.orderPlaced.value) {
          return _buildSuccessState();
        }

        return Column(
          children: [
            // ── Step indicator ──────────────────────────────────────────
            _buildStepIndicator(),

            // ── Currency selector banner/row ────────────────────────────
            _buildCurrencySelector(),

            // ── Step content ────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.topCenter,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _buildStepContent(_ctrl.currentStep.value),
              ),
            ),

            // ── Bottom action bar ────────────────────────────────────────
            _buildBottomBar(),
          ],
        );
      }),
    );
  }

  Widget _buildCurrencySelector() {
    final settings = Get.find<SettingsController>();
    final currencies = [
      {'code': 'SAR', 'label': 'SAR', 'symbol': '﷼'},
      {'code': 'USD', 'label': 'USD', 'symbol': '\$'},
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_exchange_rounded, size: 16, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'select_currency'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Obx(() => Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: currencies.map((c) {
                    final isSelected = settings.currentCurrency.value == c['code'];
                    return GestureDetector(
                      onTap: () => settings.setCurrency(c['code']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.secondary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${c['symbol']} ${c['label']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(_stepKeys.length, (index) {
          return Expanded(
            child: Obx(() {
              final isDone = index < _ctrl.currentStep.value;
              final isActive = index == _ctrl.currentStep.value;
              return GestureDetector(
                onTap: isDone ? () => _ctrl.goToStep(index) : null,
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (index == 0)
                          const Expanded(child: SizedBox())
                        else
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 2,
                              color: isDone || isActive
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? AppColors.primary
                                : isActive
                                    ? AppColors.primary
                                    : AppColors.surfaceVariant,
                            border: Border.all(
                              color: isDone || isActive
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : Icon(
                                    _stepIcons[index],
                                    size: 16,
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textHint,
                                  ),
                          ),
                        ),
                        if (index == _stepKeys.length - 1)
                          const Expanded(child: SizedBox())
                        else
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 2,
                              color: isDone
                                  ? AppColors.primary
                                  : AppColors.divider,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _stepKeys[index].tr(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive || isDone
                            ? AppColors.primary
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        }),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const Step1Address(key: ValueKey('step1'));
      case 1:
        return const Step2Shipping(key: ValueKey('step2'));
      case 2:
        return const Step3Review(key: ValueKey('step3'));
      case 3:
        return const Step4Payment(key: ValueKey('step4'));
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    return Obx(() {
      final step = _ctrl.currentStep.value;
      final isLastStep = step == 3;

      bool canProceed;
      switch (step) {
        case 0:
          canProceed = _ctrl.canProceedStep1;
          break;
        case 1:
          canProceed = _ctrl.canProceedStep2;
          break;
        case 2:
          canProceed = true;
          break;
        case 3:
          canProceed = _ctrl.selectedPaymentMethod.value != null;
          break;
        default:
          canProceed = false;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canProceed && !_ctrl.isPlacingOrder.value
                  ? () {
                      if (isLastStep) {
                        _ctrl.placeOrder();
                      } else {
                        _ctrl.nextStep();
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: canProceed ? 4 : 0,
              ),
              child: _ctrl.isPlacingOrder.value
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLastStep
                              ? 'place_order'.tr()
                              : 'next'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: canProceed
                                ? Colors.white
                                : AppColors.textHint,
                          ),
                        ),
                        if (!isLastStep) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: canProceed
                                ? Colors.white
                                : AppColors.textHint,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      );
    }).animate().slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 52,
              ),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'order_placed_title'.tr(),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
            const SizedBox(height: 12),
            Text(
              'order_placed_desc'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Get.delete<CheckoutController>();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'continue_shopping'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Don't delete here — let it persist in case user navigates back
    super.dispose();
  }
}
