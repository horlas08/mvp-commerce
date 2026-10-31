import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/constants/api_constants.dart';
import '../../../app/theme/app_colors.dart';
import '../../../controllers/checkout_controller.dart';
import '../../../controllers/settings_controller.dart';

class Step4Payment extends StatelessWidget {
  const Step4Payment({super.key});

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
            'select_payment'.tr(),
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // ── Wallet option ─────────────────────────────────────────────
          Obx(() {
            final walletMethod = {
              'id': 'wallet',
              'title': 'pay_with_wallet'.tr(),
              'type': 'wallet',
            };
            final isSelected =
                ctrl.selectedPaymentMethod.value?['id'] == 'wallet';
            return _WalletCard(
              balance: ctrl.walletBalance.value,
              isSelected: isSelected,
              settings: settings,
              onTap: () {
                ctrl.selectedPaymentMethod.value = walletMethod;
                ctrl.paymentFormData.remove('selected_account_id');
              },
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04);
          }),
          const SizedBox(height: 16),

          // ── Bank & E-Wallet Title ──────────────────────────────────────
          Text(
            'select_bank_wallet'.tr(),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 12),

          // ── Bank & E-Wallet accounts list (one by one) ─────────────────
          Obx(() {
            if (ctrl.isLoadingPayment.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            final rawMethods = List<Map<String, dynamic>>.from(ctrl.paymentMethods);
            final bankMethod = rawMethods.firstWhereOrNull((m) =>
                m['id'] == 'payment-bank' ||
                (m['title_en']?.toString().toLowerCase().contains('bank transfer') == true) ||
                (m['title_ar']?.toString().contains('حوالة') == true)) ??
                {
                  'id': 'payment-bank',
                  'title': 'حوالة بنكية 💳',
                  'title_ar': 'حوالة بنكية 💳',
                  'title_en': 'Bank Transfer 💳',
                  'fields': []
                };

            final rawAccounts = bankMethod['bank_accounts'] ?? bankMethod['raw_bank_accounts'];
            final List<Map<String, dynamic>> bankAccounts = [];
            if (rawAccounts is List && rawAccounts.isNotEmpty) {
              for (var item in rawAccounts) {
                if (item is Map) {
                  bankAccounts.add(Map<String, dynamic>.from(item));
                }
              }
            }
            if (bankAccounts.isEmpty) {
              bankAccounts.addAll(kDefaultBankAccounts);
            }

            final isBankSelected = ctrl.selectedPaymentMethod.value?['id'] == bankMethod['id'];
            final currentAccountId = ctrl.paymentFormData['selected_account_id'];
            final effectiveSelectedId = (isBankSelected && currentAccountId != null)
                ? currentAccountId
                : (isBankSelected ? bankAccounts.first['id']?.toString() : null);

            return Column(
              children: bankAccounts.asMap().entries.map((entry) {
                final index = entry.key;
                final acc = entry.value;
                final isThisSelected = isBankSelected &&
                    (effectiveSelectedId == acc['id']?.toString());

                return _BankAccountOptionCard(
                  acc: acc,
                  bankMethod: bankMethod,
                  ctrl: ctrl,
                  settings: settings,
                  isSelected: isThisSelected,
                )
                    .animate(
                      delay: Duration(milliseconds: 60 + index * 40),
                    )
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.04);
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double balance;
  final bool isSelected;
  final SettingsController settings;
  final VoidCallback onTap;

  const _WalletCard({
    required this.balance,
    required this.isSelected,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFF8A3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'pay_with_wallet'.tr(),
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'wallet_balance'.tr()}: ${settings.formatPrice(balance, 'SAR')}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
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
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border.all(
                  color: isSelected ? Colors.white : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: AppColors.primary,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

Future<XFile?> showSourcePicker(BuildContext context) async {
  final picker = ImagePicker();
  XFile? result;
  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'select_image_source'.tr(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SourceOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'camera'.tr(),
                  onTap: () async {
                    try {
                      result = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 80,
                      );
                    } catch (_) {}
                    Navigator.pop(ctx);
                  },
                ),
                _SourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'gallery'.tr(),
                  onTap: () async {
                    try {
                      result = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                    } catch (_) {}
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result;
}

const List<Map<String, dynamic>> kDefaultBankAccounts = [
  {
    "id": "acc-1",
    "bank_name_ar": "بنك الكريمي - حاسب",
    "bank_name_en": "Kuraimi Bank - Haseb",
    "account_number": "1790096",
    "account_type": "point",
    "logo_url": "/static/seed/banks/kuraimi_haseb.png",
    "asset_path": "assets/images/banks/kuraimi_haseb.png",
  },
  {
    "id": "acc-2",
    "bank_name_ar": "محفظة جيب",
    "bank_name_en": "Jeeb Wallet",
    "account_number": "770000000",
    "account_type": "wallet",
    "logo_url": "/static/seed/banks/jeeb_wallet.png",
    "asset_path": "assets/images/banks/jeeb_wallet.png",
  },
  {
    "id": "acc-3",
    "bank_name_ar": "محفظة فلوسك",
    "bank_name_en": "Floosak Wallet",
    "account_number": "770000001",
    "account_type": "wallet",
    "logo_url": "/static/seed/banks/floosak_wallet.png",
    "asset_path": "assets/images/banks/floosak_wallet.png",
  },
  {
    "id": "acc-4",
    "bank_name_ar": "محفظة كاش",
    "bank_name_en": "Cash Wallet",
    "account_number": "770000002",
    "account_type": "wallet",
    "logo_url": "/static/seed/banks/cash_wallet.png",
    "asset_path": "assets/images/banks/cash_wallet.png",
  },
  {
    "id": "acc-5",
    "bank_name_ar": "الشامل موني",
    "bank_name_en": "Shamil Money",
    "account_number": "5901094",
    "account_type": "wallet",
    "logo_url": "/static/seed/banks/shamil_money.png",
    "asset_path": "assets/images/banks/shamil_money.png",
  },
  {
    "id": "acc-6",
    "bank_name_ar": "بنك القطيبي",
    "bank_name_en": "Al Qutaibi Bank",
    "account_number": "78266666",
    "account_type": "bank",
    "logo_url": "/static/seed/banks/qutaibi_bank.png",
    "asset_path": "assets/images/banks/qutaibi_bank.png",
  },
  {
    "id": "acc-7",
    "bank_name_ar": "بنك السلام كابيتال",
    "bank_name_en": "Al Salam Capital Bank",
    "account_number": "14433",
    "account_type": "bank",
    "logo_url": "/static/seed/banks/salam_capital.png",
    "asset_path": "assets/images/banks/salam_capital.png",
  },
  {
    "id": "acc-8",
    "bank_name_ar": "الكريمي",
    "bank_name_en": "Al Kuraimi Bank",
    "account_number": "3155416717",
    "account_type": "bank",
    "logo_url": "/static/seed/banks/kuraimi_bank.png",
    "asset_path": "assets/images/banks/kuraimi_bank.png",
  },
  {
    "id": "acc-9",
    "bank_name_ar": "بنك اليمن والكويت",
    "bank_name_en": "Yemen Kuwait Bank",
    "account_number": "0236971",
    "account_type": "bank",
    "logo_url": "/static/seed/banks/ykb_bank.png",
    "asset_path": "assets/images/banks/ykb_bank.png",
  },
  {
    "id": "acc-10",
    "bank_name_ar": "بنك الامل",
    "bank_name_en": "Al-Amal Bank",
    "account_number": "282201002777",
    "account_type": "bank",
    "logo_url": "/static/seed/banks/alamal_bank.png",
    "asset_path": "assets/images/banks/alamal_bank.png",
  },
  {
    "id": "acc-11",
    "bank_name_ar": "بيس",
    "bank_name_en": "Pyes",
    "account_number": "2471501",
    "account_type": "wallet",
    "logo_url": "/static/seed/banks/pyes_wallet.png",
    "asset_path": "assets/images/banks/pyes_wallet.png",
  },
  {
    "id": "acc-12",
    "bank_name_ar": "بنك الشرق",
    "bank_name_en": "Al Sharq Bank",
    "account_number": "422333444",
    "account_type": "bank",
    "logo_url": "/static/seed/banks/alsharq_bank.png",
    "asset_path": "assets/images/banks/alsharq_bank.png",
  },
  {
    "id": "acc-13",
    "bank_name_ar": "بنك السلام كابيتال نقطة سلام باي",
    "bank_name_en": "Al Salam Capital - Salam Pay Point",
    "account_number": "119501",
    "account_type": "point",
    "logo_url": "/static/seed/banks/salam_pay.png",
    "asset_path": "assets/images/banks/salam_pay.png",
  },
];

Widget _buildBankLogoWidget(Map<String, dynamic> acc) {
  final logoUrl = acc['logo_url']?.toString();
  String? assetPath = acc['asset_path']?.toString();
  final bankName = acc['bank_name_ar']?.toString() ?? acc['bank_name_en']?.toString() ?? '';

  if (assetPath == null && logoUrl != null) {
    final filename = logoUrl.split('/').last;
    assetPath = 'assets/images/banks/$filename';
  }

  final bool isJeeb = bankName.contains('جيب') || bankName.toLowerCase().contains('jeeb');
  final bool isFloosak = bankName.contains('فلوسك') || bankName.toLowerCase().contains('floosak');
  final bool isCash = bankName.contains('كاش') || bankName.toLowerCase().contains('cash');

  if (isJeeb) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  if (isFloosak) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.payments_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  if (isCash) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF047857),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.currency_exchange_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(
      assetPath ?? '',
      width: 44,
      height: 44,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (logoUrl != null && logoUrl.isNotEmpty) {
          final fullUrl = logoUrl.startsWith('http')
              ? logoUrl
              : '${ApiConstants.baseHost}$logoUrl';
          return CachedNetworkImage(
            imageUrl: fullUrl,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance, color: AppColors.textHint, size: 22),
            ),
          );
        }
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance, color: AppColors.textHint, size: 22),
        );
      },
    ),
  );
}

class _BankAccountOptionCard extends StatelessWidget {
  final Map<String, dynamic> acc;
  final Map<String, dynamic> bankMethod;
  final CheckoutController ctrl;
  final SettingsController settings;
  final bool isSelected;

  const _BankAccountOptionCard({
    required this.acc,
    required this.bankMethod,
    required this.ctrl,
    required this.settings,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final bankName = (lang == 'ar' ? acc['bank_name_ar'] : acc['bank_name_en']) ??
        acc['bank_name_ar'] ??
        acc['bank_name'] ??
        acc['bank_name_en'] ??
        '';
    final accountNum = acc['account_number']?.toString() ?? '';
    final accountType = acc['account_type']?.toString() ?? 'account';
    final accountTypeLabel = accountType == 'point' ? 'point_number'.tr() : 'account_number'.tr();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F4FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E40AF) : AppColors.divider,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF1E40AF).withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              ctrl.selectedPaymentMethod.value = bankMethod;
              ctrl.paymentFormData['selected_account_id'] = acc['id']?.toString() ?? '';
              ctrl.paymentFormData['selected_bank_name'] = bankName;
              ctrl.paymentFormData['selected_account_number'] = accountNum;
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Radio Indicator matching Image 1
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFFCBD5E1),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Bank / Wallet Logo
                  _buildBankLogoWidget(acc),
                  const SizedBox(width: 14),
                  // Title & Account Number
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bankName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$accountTypeLabel: $accountNum',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isSelected) ...[
            const Divider(height: 1, color: Color(0xFFDBEAFE)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account / Point number box + Copy button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              accountTypeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              accountNum,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E40AF),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: accountNum));
                            Get.rawSnackbar(
                              messageText: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'account_number_copied'.tr(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF1E40AF),
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                              margin: const EdgeInsets.all(12),
                              borderRadius: 12,
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: Text('copy'.tr(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E40AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Upload Receipt
                  Text(
                    'upload_receipt_optional'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'receipt_quick_confirm_tip'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    final hasProof = ctrl.paymentProofImage.value != null;
                    final proofPath = ctrl.paymentProofImage.value?.path;
                    return _UploadDropzone(
                      hasFile: hasProof,
                      fileName: proofPath?.split('/').last,
                      imagePath: proofPath,
                      onTap: () async {
                        final img = await showSourcePicker(context);
                        if (img != null) {
                          ctrl.paymentProofImage.value = img;
                          ctrl.paymentFormData['receipt_proof'] = img.path;
                        }
                      },
                      onClear: () {
                        ctrl.paymentProofImage.value = null;
                        ctrl.paymentFormData.remove('receipt_proof');
                      },
                    );
                  }),
                  const SizedBox(height: 14),

                  // Depositor Name
                  TextFormField(
                    initialValue: ctrl.paymentFormData['depositor_name'],
                    onChanged: (v) => ctrl.paymentFormData['depositor_name'] = v,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'depositor_name'.tr(),
                      hintText: 'enter_depositor_name'.tr(),
                      labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Transfer / Reference Number
                  TextFormField(
                    initialValue: ctrl.paymentFormData['ref_number'],
                    onChanged: (v) => ctrl.paymentFormData['ref_number'] = v,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'transfer_or_ref_number'.tr(),
                      hintText: 'enter_transfer_or_ref_number'.tr(),
                      labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PaymentFormSheet extends StatelessWidget {
  final Map<String, dynamic> method;
  final List<Map<String, dynamic>> fields;
  final CheckoutController ctrl;

  const PaymentFormSheet({
    super.key,
    required this.method,
    required this.fields,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.secondary, size: 22),
              const SizedBox(width: 8),
              Text(
                'payment_details'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ).animate().fadeIn().slideX(begin: -0.1),
          if (method['details'] != null && method['details'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.secondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      method['details'].toString(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          ],
          const SizedBox(height: 20),

          // Dynamic fields from admin
          ...fields.map((field) {
            final key = field['key']?.toString() ?? field['label']?.toString() ?? '';
            final label = field['label']?.toString() ?? key;
            final type = field['type']?.toString() ?? 'text';

            if (type == 'file') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final path = ctrl.paymentFormData[key];
                      final hasFile = path != null && path.isNotEmpty;
                      return _UploadDropzone(
                        hasFile: hasFile,
                        fileName: path?.split('/').last,
                        imagePath: path,
                        onTap: () async {
                          final img = await showSourcePicker(context);
                          if (img != null) {
                            ctrl.paymentFormData[key] = img.path;
                          }
                        },
                        onClear: () {
                          ctrl.paymentFormData.remove(key);
                        },
                      );
                    }),
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              );
            }

            if (type == 'select') {
              final rawOptions = field['options'];
              final List<String> options = [];
              if (rawOptions is List) {
                options.addAll(rawOptions.map((e) => e.toString()));
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Obx(() {
                  final currentValue = ctrl.paymentFormData[key];
                  final String? selectValue = (currentValue != null && options.contains(currentValue)) ? currentValue : null;

                  return DropdownButtonFormField<String>(
                    value: selectValue,
                    hint: Text(
                      'select_option'.tr(args: [label]),
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.secondary,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: options.map((opt) {
                      return DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ctrl.paymentFormData[key] = v;
                      }
                    },
                  );
                }).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                initialValue: ctrl.paymentFormData[key],
                onChanged: (v) => ctrl.paymentFormData[key] = v,
                keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.secondary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
            );
          }),
        ],
      ),
    );
  }
}

class _UploadDropzone extends StatelessWidget {
  final bool hasFile;
  final String? fileName;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _UploadDropzone({
    required this.hasFile,
    required this.fileName,
    this.imagePath,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: hasFile ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: hasFile
            ? Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (imagePath != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(imagePath!),
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.check_circle, color: AppColors.success, size: 36),
                              ),
                            )
                          else
                            const Icon(Icons.check_circle, color: AppColors.success, size: 36),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              fileName ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textHint, size: 20),
                      onPressed: onClear,
                    ),
                  ),
                ],
              )
            : Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black87, width: 2),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.black87,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
