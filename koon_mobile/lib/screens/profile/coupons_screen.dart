import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../app/utils/app_snackbar.dart';
import '../../services/coupon_service.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final CouponService _couponService = CouponService();
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);
    final lang = context.locale.languageCode;
    final data = await _couponService.getCoupons(lang: lang);
    setState(() {
      _coupons = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('coupons'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _coupons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('No coupons available'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = _coupons[index];
                    final code = coupon['code'] ?? '';
                    final desc = coupon['description'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    code,
                                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    desc,
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  if (coupon['min_order_amount'] != null && coupon['min_order_amount'] > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${'Min order:'.tr()} ${coupon['min_order_amount']} SAR',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                AppSnackbar.success(context, 'link_copied'.tr(), duration: const Duration(seconds: 2));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('Copy'.tr(), style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
