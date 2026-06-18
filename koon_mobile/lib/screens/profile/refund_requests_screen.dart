import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
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

  void _showRequestRefundDialog() {
    final formKey = GlobalKey<FormState>();
    final orderIdCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Request Refund'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: orderIdCtrl,
                  decoration: InputDecoration(labelText: 'Order ID'.tr()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Reason for Refund'.tr()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    await _refundService.requestRefund(
                      orderId: orderIdCtrl.text.trim(),
                      reason: reasonCtrl.text.trim(),
                    );
                    _loadRefunds();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Submit Request'.tr(), style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('refund_requests'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _refunds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.money_off_outlined, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('No refund requests'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _refunds.length,
                  itemBuilder: (context, index) {
                    final req = _refunds[index];
                    final status = req['status'] ?? 'pending';
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
                                Text('Order ID: ${(req['order_id'] ?? '').toString().substring(0, 8)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Text(status.toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Reason:'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(req['reason'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                            if (req['admin_note'] != null) ...[
                              const SizedBox(height: 10),
                              Text('Admin Note:'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                              Text(req['admin_note'], style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showRequestRefundDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
