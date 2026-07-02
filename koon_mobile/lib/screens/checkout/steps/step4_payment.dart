import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
              onTap: () => ctrl.selectedPaymentMethod.value = walletMethod,
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.04);
          }),
          const SizedBox(height: 12),

          // ── Admin payment methods ──────────────────────────────────────
          Obx(() {
            if (ctrl.isLoadingPayment.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }
            return Column(
              children: ctrl.paymentMethods.asMap().entries.map((entry) {
                final index = entry.key;
                final method = entry.value;
                return _AdminPaymentCard(
                  method: method,
                  ctrl: ctrl,
                  settings: settings,
                )
                    .animate(
                      delay: Duration(milliseconds: 60 + index * 60),
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

class _AdminPaymentCard extends StatelessWidget {
  final Map<String, dynamic> method;
  final CheckoutController ctrl;
  final SettingsController settings;

  const _AdminPaymentCard({
    required this.method,
    required this.ctrl,
    required this.settings,
  });

  bool get isSelected =>
      ctrl.selectedPaymentMethod.value?['id'] == method['id'];

  @override
  Widget build(BuildContext context) {
    final fields =
        List<Map<String, dynamic>>.from(method['fields'] ?? []);
    final imageUrl = method['image_url']?.toString();

    return Obx(() {
      final selected = ctrl.selectedPaymentMethod.value?['id'] == method['id'];
      return Column(
        children: [
          GestureDetector(
            onTap: () => ctrl.selectedPaymentMethod.value = method,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? AppColors.secondary : AppColors.divider,
                  width: selected ? 2 : 1.5,
                ),
                color: selected
                    ? AppColors.secondarySurface
                    : AppColors.surface,
              ),
              child: Row(
                children: [
                  // Payment logo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                          )
                        : const Icon(
                            Icons.payment,
                            color: AppColors.textHint,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['title'] ?? 'Payment',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: selected
                                ? AppColors.secondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (method['description'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            method['description'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.secondary : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.secondary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // (PaymentForm has been moved to a modal triggered on Place Order)
        ],
      );
    });
  }
}

class PaymentFormSheet extends StatelessWidget {
  final Map<String, dynamic> method;
  final List<Map<String, dynamic>> fields;
  final CheckoutController ctrl;

  const PaymentFormSheet({
    required this.method,
    required this.fields,
    required this.ctrl,
  });

  Future<XFile?> _showSourcePicker(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    final hasFileField = fields.any((f) => (f['type']?.toString() ?? 'text') == 'file');

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
                        onTap: () async {
                          final img = await _showSourcePicker(context);
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
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.border),
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
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
          }),

          // Payment proof image upload (only if no dynamic file field)
          if (!hasFileField) ...[
            const SizedBox(height: 8),
            Text(
              'upload_proof'.tr(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 8),
          Obx(() => _UploadDropzone(
                hasFile: ctrl.paymentProofImage.value != null,
                fileName: ctrl.paymentProofImage.value?.name,
                onTap: () async {
                  final img = await _showSourcePicker(context);
                  if (img != null) ctrl.paymentProofImage.value = img;
                },
                onClear: () {
                  ctrl.paymentProofImage.value = null;
                },
              )).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
          ],
        ],
      ),
    );
  }
}

class _UploadDropzone extends StatelessWidget {
  final bool hasFile;
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _UploadDropzone({
    required this.hasFile,
    required this.fileName,
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
        height: 120,
        decoration: BoxDecoration(
          color: hasFile ? AppColors.success.withOpacity(0.05) : AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile ? AppColors.success : AppColors.border,
            width: hasFile ? 2 : 1.5,
          ),
        ),
        child: hasFile
            ? Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            fileName ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'tap_to_upload'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'supported_formats'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
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
