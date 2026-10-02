import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/app_colors.dart';
import '../../../controllers/checkout_controller.dart';
import '../steps/step4_payment.dart' show showSourcePicker;

class TransferPaymentSheet extends StatefulWidget {
  final CheckoutController ctrl;
  final Map<String, dynamic> method;

  const TransferPaymentSheet({
    super.key,
    required this.ctrl,
    required this.method,
  });

  @override
  State<TransferPaymentSheet> createState() => _TransferPaymentSheetState();
}

class _TransferPaymentSheetState extends State<TransferPaymentSheet> {
  late final TextEditingController _depositorCtrl;
  late final TextEditingController _refCtrl;
  XFile? _selectedProof;
  String? _depositorError;
  String? _refError;
  bool _isSubmitting = false;


  @override
  void initState() {
    super.initState();
    _depositorCtrl = TextEditingController(
      text: widget.ctrl.paymentFormData['depositor_name'] ?? '',
    );
    _refCtrl = TextEditingController(
      text: widget.ctrl.paymentFormData['reference_number'] ?? '',
    );
    _selectedProof = widget.ctrl.paymentProofImage.value;
  }

  @override
  void dispose() {
    _depositorCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final depositor = _depositorCtrl.text.trim();
    final ref = _refCtrl.text.trim();

    setState(() {
      _depositorError = depositor.isEmpty ? 'depositor_name_required'.tr() : null;
      _refError = ref.isEmpty ? 'ref_number_required'.tr() : null;
    });

    if (_depositorError != null || _refError != null) {
      return;
    }

    widget.ctrl.paymentFormData['depositor_name'] = depositor;
    widget.ctrl.paymentFormData['reference_number'] = ref;
    widget.ctrl.paymentFormData['transfer_reference'] = ref;
    widget.ctrl.paymentProofImage.value = _selectedProof;

    setState(() => _isSubmitting = true);

    await widget.ctrl.placeOrder();

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (widget.ctrl.orderPlaced.value) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sheet title & close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'bank_transfer_details'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textHint),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Quick confirmation tip banner ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Color(0xFFF57F17),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'receipt_quick_confirm_tip'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8D6E16),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05),
              const SizedBox(height: 18),

              // ── Field 1: Depositor Name (Required) ──
              Row(
                children: [
                  Text(
                    'depositor_name'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _depositorCtrl,
                onChanged: (_) {
                  if (_depositorError != null) {
                    setState(() => _depositorError = null);
                  }
                },
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'enter_depositor_name'.tr(),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  errorText: _depositorError,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
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
                    borderSide: const BorderSide(
                      color: AppColors.secondary,
                      width: 1.8,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Field 2: Transfer / Reference Number (Required) ──
              Row(
                children: [
                  Text(
                    'transfer_or_ref_number'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _refCtrl,
                onChanged: (_) {
                  if (_refError != null) {
                    setState(() => _refError = null);
                  }
                },
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'enter_transfer_or_ref_number'.tr(),
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: const Icon(
                    Icons.tag_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  errorText: _refError,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
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
                    borderSide: const BorderSide(
                      color: AppColors.secondary,
                      width: 1.8,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Field 3: Upload Receipt (Optional) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'upload_receipt_optional'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      'optional'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Upload receipt picker card
              _buildReceiptPicker(),
              const SizedBox(height: 24),

              // ── Submit / Place Order Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting || widget.ctrl.isPlacingOrder.value
                      ? null
                      : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: _isSubmitting || widget.ctrl.isPlacingOrder.value
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'confirm_and_place_order'.tr(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptPicker() {
    final proof = _selectedProof;
    final hasFile = proof != null;

    if (hasFile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success, width: 1.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(proof.path),
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: AppColors.surfaceVariant,
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'receipt_attached'.tr(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    proof.name.isNotEmpty
                        ? proof.name
                        : proof.path.split('/').last,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFE53935),
                size: 22,
              ),
              onPressed: () {
                setState(() => _selectedProof = null);
                widget.ctrl.paymentProofImage.value = null;
                widget.ctrl.paymentFormData.remove('receipt_proof');
              },
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final img = await showSourcePicker(context);
        if (img != null) {
          setState(() => _selectedProof = img);
          widget.ctrl.paymentProofImage.value = img;
          widget.ctrl.paymentFormData['receipt_proof'] = img.path;
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'tap_to_upload_receipt'.tr(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PNG, JPG up to 10MB',
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
