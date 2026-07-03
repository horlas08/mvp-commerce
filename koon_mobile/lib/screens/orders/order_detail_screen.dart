import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/order_controller.dart';
import '../webview/webview_screen.dart';
import '../../app/constants/api_constants.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _order;
  bool _isSubmittingRefund = false;
  bool _isSubmittingCancel = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  String get _orderId => (_order['id'] ?? '').toString();
  String get _shortId => _orderId.length >= 8 ? _orderId.substring(0, 8).toUpperCase() : _orderId.toUpperCase();
  String get _status => _order['status'] ?? 'pending';
  String get _paymentStatus => _order['payment_status'] ?? 'not_required';
  double get _total => double.tryParse(_order['total']?.toString() ?? '0') ?? 0;
  List<dynamic> get _items => _order['items'] as List? ?? [];
  Map<String, dynamic>? get _shippingAddress => _order['shipping_address'] as Map<String, dynamic>?;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed': return AppColors.info;
      case 'processing': return AppColors.secondary;
      case 'shipped': return AppColors.secondaryLight;
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  Color _getPaymentStatusColor(String ps) {
    switch (ps) {
      case 'approved':
      case 'not_required': return AppColors.success;
      case 'rejected': return AppColors.error;
      default: return AppColors.warning;
    }
  }

  Future<void> _downloadInvoice() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Koon Commerce', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, color: const PdfColor.fromInt(0xFFFF6B00))),
              ],
            ),
            pw.Divider(thickness: 2, color: const PdfColor.fromInt(0xFFFF6B00)),
            pw.SizedBox(height: 12),
            pw.Text('Order #$_shortId', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: ${(_order['created_at'] ?? '').toString().split('T').first}'),
            pw.Text('Status: $_status'),
            pw.SizedBox(height: 20),
            pw.Text('ITEMS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Divider(),
            ..._items.map((item) {
              final title = item['title'] ?? '';
              final qty = item['quantity'] ?? 1;
              final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text(title, style: const pw.TextStyle(fontSize: 12))),
                  pw.Text('x$qty', style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(width: 20),
                  pw.Text('${(price * qty).toStringAsFixed(2)} SAR', style: const pw.TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
            pw.Divider(thickness: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TOTAL: ${_total.toStringAsFixed(2)} SAR',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        );
      },
    ));

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_$_shortId.pdf',
    );
  }

  void _showRefundBottomSheet() {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('request_refund'.tr(),
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('order_id_label'.tr(args: [_shortId]),
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'refund_reason'.tr(),
                hintText: 'describe_issue'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            StatefulBuilder(builder: (ctx2, setSt) {
              return ElevatedButton(
                onPressed: _isSubmittingRefund ? null : () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    Get.snackbar('error'.tr(), 'please_fill_all_fields'.tr(), snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  setSt(() => _isSubmittingRefund = true);
                  final success = await Get.find<OrderController>()
                      .submitRefund(orderId: _orderId, reason: reason);
                  setSt(() => _isSubmittingRefund = false);
                  if (success && ctx.mounted) {
                    Navigator.pop(ctx);
                    Get.snackbar('success'.tr(), 'refund_submitted'.tr(), snackPosition: SnackPosition.BOTTOM);
                  } else {
                    Get.snackbar('error'.tr(), 'something_went_wrong'.tr(), snackPosition: SnackPosition.BOTTOM);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmittingRefund
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('submit'.tr()),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_status);
    final paymentStatusColor = _getPaymentStatusColor(_paymentStatus);
    final dateStr = (_order['created_at'] ?? '').toString().split('T').first;
    final paymentMethodId = _order['payment_method_id'] ?? '';
    final paymentProofUrl = _order['payment_proof_url'];
    final String cartType = (_order['cart_type'] ?? 'internal').toString();
    final bool allowTeamReview = _order['allow_team_review'] ?? false;
    final String shippingType = (_order['shipping_type'] ?? 'home').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text('#$_shortId', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'download_invoice'.tr(),
            onPressed: _downloadInvoice,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Row
            _buildSectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('order_status'.tr(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('order_status_$_status'.tr(),
                              style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('payment_status'.tr(), style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: paymentStatusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('payment_status_$_paymentStatus'.tr(),
                            style: GoogleFonts.inter(color: paymentStatusColor, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 12),

            // Order Info
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.tag, 'order_id'.tr(), '#$_shortId'),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.calendar_today_outlined, 'order_date'.tr(), dateStr),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.store_outlined, 'source'.tr(), cartType.toUpperCase()),
                  if (allowTeamReview) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.group_outlined, 'team_review'.tr(), 'enabled'.tr()),
                  ],
                  if (shippingType.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.local_shipping_outlined, 'shipping_type'.tr(), shippingType.tr()),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

            const SizedBox(height: 12),

            // Items
            _buildSectionHeader('items'.tr()),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final item = entry.value as Map<String, dynamic>;
              final externalUrl = item['external_url'] as String?;
              final title = item['title'] ?? '';
              final qty = item['quantity'] ?? 1;
              final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
              final imageUrl = item['image_url'];
              final source = item['source'] ?? 'internal';

              return GestureDetector(
                onTap: externalUrl != null && externalUrl.isNotEmpty
                    ? () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => WebViewScreen(initialUrl: externalUrl, siteName: source)))
                    : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: imageUrl != null
                              ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _placeholderImage())
                              : _placeholderImage(),
                        ),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ),
                                  if (externalUrl != null && externalUrl.isNotEmpty)
                                    const Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(source.toUpperCase(),
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  ),
                                  const Spacer(),
                                  Text('x$qty', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(width: 8),
                                  Text('${(price * qty).toStringAsFixed(2)} SAR',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: Duration(milliseconds: entry.key * 60)).fadeIn(duration: 300.ms).slideX(begin: 0.05),
              );
            }),

            const SizedBox(height: 12),

            // Total
            _buildSectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('total'.tr(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${_total.toStringAsFixed(2)} SAR',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 12),

            // Payment Info
            if (paymentMethodId.isNotEmpty)
              _buildSectionCard(
                title: 'payment_info'.tr(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.payment_outlined, 'payment_method'.tr(),
                        paymentMethodId == 'wallet' ? 'wallet'.tr() : paymentMethodId),
                    if (paymentProofUrl != null) ...[
                      const SizedBox(height: 12),
                      Text('payment_proof'.tr(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          paymentProofUrl.startsWith('http') ? paymentProofUrl : '${ApiConstants.baseHost}$paymentProofUrl',
                          height: 180, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80, color: AppColors.surfaceVariant,
                            child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textHint)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 450.ms),

            if (_shippingAddress != null) ...[
              const SizedBox(height: 12),
              _buildSectionCard(
                title: 'shipping_address'.tr(),
                child: Text(
                  _formatAddress(_shippingAddress!),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                ),
              ).animate().fadeIn(duration: 500.ms),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            if (_status != 'cancelled' && _status != 'delivered') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadInvoice,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text('download_invoice'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
              const SizedBox(height: 10),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showRefundBottomSheet,
                icon: const Icon(Icons.undo_outlined),
                label: Text('request_refund'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ).animate().fadeIn(duration: 650.ms).slideY(begin: 0.1),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child, String? title}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(10)),
      child: const Center(child: Icon(Icons.image_outlined, color: AppColors.textHint)),
    );
  }

  String _formatAddress(Map<String, dynamic> addr) {
    final parts = <String>[];
    if (addr['street'] != null) parts.add(addr['street'].toString());
    if (addr['district'] != null) parts.add(addr['district'].toString());
    if (addr['city'] != null) parts.add(addr['city'].toString());
    if (addr['state'] != null) parts.add(addr['state'].toString());
    if (addr['zip_code'] != null) parts.add(addr['zip_code'].toString());
    if (addr['country'] != null) parts.add(addr['country'].toString());
    if (addr['address_id'] != null && parts.isEmpty) return 'Address ID: ${addr['address_id']}';
    return parts.isNotEmpty ? parts.join(', ') : 'N/A';
  }
}
