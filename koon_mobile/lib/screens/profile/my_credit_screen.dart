import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';

class MyCreditScreen extends StatelessWidget {
  const MyCreditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('my_credit'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Available Balance'.tr(),
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Obx(() => Text(
                        '${authController.userCredit.toStringAsFixed(2)} ' + 'SAR'.tr(),
                        style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Credit Details'.tr(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Active Card'.tr(), '**** **** **** 4321'),
                    const Divider(height: 24),
                    _buildDetailRow('Account Status'.tr(), 'Verified'.tr(), valueColor: AppColors.success),
                    const Divider(height: 24),
                    _buildDetailRow('Refund Method'.tr(), 'Store Credit'.tr()),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Get.snackbar('top_up'.tr(), 'payment_gateway_loading'.tr(), snackPosition: SnackPosition.BOTTOM);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Top Up Balance'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}
