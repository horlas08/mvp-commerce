import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../services/wallet_service.dart';
import '../../app/utils/app_snackbar.dart';

class MyCreditScreen extends StatefulWidget {
  const MyCreditScreen({super.key});

  @override
  State<MyCreditScreen> createState() => _MyCreditScreenState();
}

class _MyCreditScreenState extends State<MyCreditScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final SettingsController _settingsController = Get.find<SettingsController>();
  final WalletService _walletService = WalletService();

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingTransactions = true);
    await _authController.refreshProfile();
    final txs = await _walletService.getTransactions();
    if (mounted) {
      setState(() {
        _transactions = txs;
        _isLoadingTransactions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('my_credit'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Balance Card ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'available_balance'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      final balance = _authController.userCredit;
                      return Text(
                        _settingsController.formatPrice(balance, 'SAR'),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _showTopUpBottomSheet(context, lang),
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary),
                        label: Text(
                          'top_up_balance'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Dummy Credit Details (commented out) ───────────────────
              // Text(
              //   'Credit Details'.tr(),
              //   style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              // ),
              // const SizedBox(height: 12),
              // Card(
              //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              //   child: Padding(
              //     padding: const EdgeInsets.all(16.0),
              //     child: Column(
              //       children: [
              //         _buildDetailRow('Active Card'.tr(), '**** **** **** 4321'),
              //         const Divider(height: 24),
              //         _buildDetailRow('Account Status'.tr(), 'Verified'.tr(), valueColor: AppColors.success),
              //         const Divider(height: 24),
              //         _buildDetailRow('Refund Method'.tr(), 'Store Credit'.tr()),
              //       ],
              //     ),
              //   ),
              // ),

              // ── Recent Transactions ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'recent_transactions'.tr(),
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  if (_transactions.isNotEmpty)
                    Text(
                      '${_transactions.length}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoadingTransactions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_transactions.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textHint.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'no_transactions'.tr(),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final isCredit = (tx['type'] ?? '').toString().toLowerCase() == 'credit';
                    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                    final reason = tx['reason']?.toString() ?? (isCredit ? 'Top-Up' : 'Order Payment');
                    final dateStr = tx['created_at']?.toString();
                    String formattedDate = '';
                    if (dateStr != null) {
                      try {
                        final parsed = DateTime.parse(dateStr).toLocal();
                        formattedDate = DateFormat('yyyy/MM/dd - hh:mm a').format(parsed);
                      } catch (_) {
                        formattedDate = dateStr;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: (isCredit ? AppColors.success : AppColors.error).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isCredit ? AppColors.success : AppColors.error,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reason,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (formattedDate.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isCredit ? "+" : "-"}${_settingsController.formatPrice(amount, 'SAR')}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isCredit ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// White bottom sheet showing available top-up methods
  void _showTopUpBottomSheet(BuildContext context, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'select_top_up_method'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  lang == 'ar'
                      ? 'اختر الطريقة المناسبة لإضافة رصيد إلى محفظتك'
                      : 'Choose how you want to add credit to your wallet',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // ── 1. Coupon / Gift Voucher (ACTIVE) ────────────────────
                _buildMethodTile(
                  icon: Icons.confirmation_number_outlined,
                  iconBgColor: AppColors.primary.withOpacity(0.12),
                  iconColor: AppColors.primary,
                  title: 'coupon_voucher'.tr(),
                  subtitle: 'coupon_voucher_desc'.tr(),
                  isActive: true,
                  onTap: () {
                    Navigator.pop(bottomSheetCtx);
                    _showCouponRedeemDialog(context, lang);
                  },
                ),

                const SizedBox(height: 12),

                // ── 2. Credit / Debit Card (COMING SOON) ─────────────────
                _buildMethodTile(
                  icon: Icons.credit_card_outlined,
                  iconBgColor: Colors.blue.withOpacity(0.1),
                  iconColor: Colors.blue,
                  title: 'credit_debit_card'.tr(),
                  subtitle: 'Visa, Mastercard, Mada',
                  isActive: false,
                  badgeText: lang == 'ar' ? 'قريباً' : 'Soon',
                ),

                const SizedBox(height: 12),

                // ── 3. Bank Transfer (COMING SOON) ───────────────────────
                _buildMethodTile(
                  icon: Icons.account_balance_outlined,
                  iconBgColor: Colors.purple.withOpacity(0.1),
                  iconColor: Colors.purple,
                  title: 'bank_transfer'.tr(),
                  subtitle: lang == 'ar' ? 'إيداع مباشر عبر الحساب البنكي' : 'Direct bank deposit',
                  isActive: false,
                  badgeText: lang == 'ar' ? 'قريباً' : 'Soon',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Method selection tile
  Widget _buildMethodTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isActive,
    String? badgeText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: isActive ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary.withOpacity(0.3) : AppColors.divider.withOpacity(0.5),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textHint.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isActive ? AppColors.primary : AppColors.textHint.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  /// White bottom sheet / dialog for entering coupon code
  void _showCouponRedeemDialog(BuildContext context, String lang) {
    final codeController = TextEditingController();
    final isSubmitting = false.obs;
    final errorMessage = ''.obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (couponSheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(couponSheetCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header icon
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                'enter_coupon_code'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                lang == 'ar'
                    ? 'أدخل كود الكوبون أو قسيمة الشحن لإضافة الرصيد إلى حسابك فوراً'
                    : 'Enter your coupon or voucher code to top up your balance instantly',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // In-sheet Error Banner
              Obx(() {
                if (errorMessage.value.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage.value,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Code input
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                onChanged: (_) {
                  if (errorMessage.value.isNotEmpty) {
                    errorMessage.value = '';
                  }
                },
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. WELCOME10',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
                  suffixIcon: TextButton(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                      if (clipboardData?.text != null) {
                        codeController.text = clipboardData!.text!.trim().toUpperCase();
                        errorMessage.value = '';
                      }
                    },
                    child: Text(
                      'paste'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Submit Button
              Obx(() => SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting.value
                          ? null
                          : () async {
                              final code = codeController.text.trim();
                              if (code.isEmpty) {
                                final msg = lang == 'ar' ? 'يرجى إدخال كود الكوبون' : 'Please enter a coupon code';
                                errorMessage.value = msg;
                                Get.snackbar('error'.tr(), msg, snackPosition: SnackPosition.TOP);
                                return;
                              }

                              isSubmitting.value = true;
                              errorMessage.value = '';
                              final res = await _walletService.topUpWithCoupon(code);
                              isSubmitting.value = false;

                              if (res['success'] == true) {
                                Navigator.pop(couponSheetCtx);
                                final double newBal = (res['new_balance'] as num?)?.toDouble() ?? 0.0;
                                final double added = (res['amount_added'] as num?)?.toDouble() ?? 0.0;

                                _authController.updateCreditBalance(newBal);
                                _loadData();

                                if (mounted) {
                                  AppSnackbar.success(
                                    context,
                                    lang == 'ar'
                                        ? 'تم شحن $added ريال إلى رصيدك بنجاح!'
                                        : 'Successfully added $added SAR to your balance!',
                                  );
                                }
                              } else {
                                final errorMsg = res['message']?.toString() ?? (lang == 'ar' ? 'فشل شحن الكوبون' : 'Failed to redeem coupon');
                                errorMessage.value = errorMsg;
                                Get.snackbar(
                                  'error'.tr(),
                                  errorMsg,
                                  snackPosition: SnackPosition.TOP,
                                  backgroundColor: AppColors.error.withOpacity(0.9),
                                  colorText: Colors.white,
                                  margin: const EdgeInsets.all(16),
                                  borderRadius: 12,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'redeem_coupon'.tr(),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  // ── Helper method for commented out dummy details ────────────────────────
  // Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
  //       Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
  //     ],
  //   );
  // }
}
