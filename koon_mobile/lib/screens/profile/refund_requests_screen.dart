import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart' hide Trans;
import '../../app/theme/app_colors.dart';
import '../../controllers/order_controller.dart';
import '../../services/refund_service.dart';

class RefundRequestsScreen extends StatefulWidget {
  const RefundRequestsScreen({super.key});

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> {
  final RefundService _refundService = RefundService();
  List<Map<String, dynamic>> _refunds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRefunds();
  }

  Future<void> _loadRefunds() async {
    setState(() => _isLoading = true);
    final data = await _refundService.getRefunds();
    setState(() {
      _refunds = data;
      _isLoading = false;
    });
  }

  Future<void> _cancelRefund(String refundId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('cancel_refund'.tr()),
        content: Text('confirm_cancel_refund'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('no'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('yes'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await Get.find<OrderController>().cancelRefund(refundId);
      if (success) {
        Get.snackbar('success'.tr(), 'refund_cancelled_success'.tr(), snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('error'.tr(), 'failed_to_cancel_refund'.tr(), snackPosition: SnackPosition.BOTTOM);
      }
      _loadRefunds();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('refund_requests'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadRefunds,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _refunds.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.money_off_outlined, size: 64, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text('No refund requests'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _refunds.length,
                    itemBuilder: (context, index) {
                      final req = _refunds[index];
                      final status = req['status'] ?? 'pending';
                      final refundId = req['id'] ?? '';
                      final orderId = req['order_id'] ?? '';
                      final orderShortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();
                      Color statusColor = AppColors.warning;
                      if (status == 'approved' || status == 'completed') statusColor = AppColors.success;
                      if (status == 'rejected') statusColor = AppColors.error;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'order_id_label'.tr(args: [orderShortId]),
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      'refund_status_$status'.tr().toUpperCase(),
                                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Reason:'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(req['reason'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                              if (req['admin_note'] != null && req['admin_note'].toString().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Admin Note:'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                                Text(req['admin_note'], style: const TextStyle(color: AppColors.textSecondary)),
                              ],
                              if (status == 'pending') ...[
                                const SizedBox(height: 12),
                                const Divider(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _cancelRefund(refundId),
                                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                                    label: Text('cancel_refund'.tr(), style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
