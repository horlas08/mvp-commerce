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
import '../../app/utils/app_snackbar.dart';
import '../../app/utils/url_helper.dart';
import '../../services/api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _order;
  bool _isSubmittingRefund = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  String get _orderId => (_order['id'] ?? '').toString();
  String get _shortId => _orderId.length >= 8 ? _orderId.substring(0, 8).toUpperCase() : _orderId.toUpperCase();
  String get _status => _order['status'] ?? 'pending';
  String get _paymentStatus => _order['payment_status'] ?? 'not_required';
  double get _total => double.tryParse(_order['total']?.toString() ?? '0') ?? 0;
  List<dynamic> get _items => _order['items'] as List? ?? [];
  Map<String, dynamic>? get _shippingAddress =>
      _order['shipping_address'] != null ? Map<String, dynamic>.from(_order['shipping_address'] as Map) : null;
  bool get _canEditAddress => _status == 'pending' || _status == 'confirmed';

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
                pw.Text('Widdi Commerce', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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

  void _showEditShippingAddressBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final current = _shippingAddress ?? {};
    final nameCtrl = TextEditingController(text: current['full_name'] ?? current['recipient_name'] ?? '');
    final phoneCtrl = TextEditingController(text: current['phone'] ?? '');
    final streetCtrl = TextEditingController(text: current['street'] ?? '');
    final cityCtrl = TextEditingController(text: current['city'] ?? '');
    final stateCtrl = TextEditingController(text: current['state'] ?? '');
    final notesCtrl = TextEditingController(text: current['notes'] ?? '');
    final lang = context.locale.languageCode;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomCtx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 16),
                  Text(
                    lang == 'ar' ? 'تعديل عنوان التوصيل' : 'Edit Delivery Address',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: lang == 'ar' ? 'اسم المستلم' : 'Recipient Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? (lang == 'ar' ? 'هذا الحقل مطلوب' : 'Required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang == 'ar' ? 'رقم الهاتف' : 'Phone Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? (lang == 'ar' ? 'هذا الحقل مطلوب' : 'Required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: streetCtrl,
                    decoration: InputDecoration(
                      labelText: 'street'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? (lang == 'ar' ? 'هذا الحقل مطلوب' : 'Required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'city'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? (lang == 'ar' ? 'هذا الحقل مطلوب' : 'Required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stateCtrl,
                    decoration: InputDecoration(
                      labelText: lang == 'ar' ? 'المحافظة / المنطقة' : 'State / Province',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: lang == 'ar' ? 'ملاحظات التوصيل (اختياري)' : 'Delivery Notes (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);

                              final updatedAddress = Map<String, dynamic>.from(_shippingAddress ?? {});
                              updatedAddress['full_name'] = nameCtrl.text.trim();
                              updatedAddress['recipient_name'] = nameCtrl.text.trim();
                              updatedAddress['phone'] = phoneCtrl.text.trim();
                              updatedAddress['street'] = streetCtrl.text.trim();
                              updatedAddress['city'] = cityCtrl.text.trim();
                              if (stateCtrl.text.trim().isNotEmpty) {
                                updatedAddress['state'] = stateCtrl.text.trim();
                              } else {
                                updatedAddress.remove('state');
                              }
                              if (notesCtrl.text.trim().isNotEmpty) {
                                updatedAddress['notes'] = notesCtrl.text.trim();
                              } else {
                                updatedAddress.remove('notes');
                              }

                              try {
                                final response = await ApiService().dio.patch(
                                  '${ApiConstants.baseUrl}/orders/$_orderId/shipping-address',
                                  data: {'shipping_address': updatedAddress},
                                );
                                if (bottomCtx.mounted) {
                                  Navigator.pop(bottomCtx);
                                }
                                if (!mounted) return;
                                if (response.statusCode == 200) {
                                  setState(() {
                                    if (response.data is Map && response.data['shipping_address'] != null) {
                                      _order['shipping_address'] = response.data['shipping_address'];
                                    } else {
                                      _order['shipping_address'] = updatedAddress;
                                    }
                                  });
                                  AppSnackbar.success(
                                    null,
                                    lang == 'ar'
                                        ? 'تم تحديث عنوان التوصيل بنجاح'
                                        : 'Delivery address updated successfully',
                                  );
                                } else {
                                  AppSnackbar.error(
                                    null,
                                    lang == 'ar' ? 'فشل في تحديث العنوان' : 'Failed to update address',
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                setModalState(() => isSaving = false);
                                AppSnackbar.error(
                                  null,
                                  lang == 'ar' ? 'حدث خطأ أثناء حفظ العنوان' : 'Error saving address',
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              lang == 'ar' ? 'حفظ عنوان التوصيل' : 'Save Delivery Address',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                        builder: (_) => WebViewScreen(initialUrl: UrlHelper.convertToArabicUrl(externalUrl), siteName: source)))
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

            if (_shippingAddress != null || _canEditAddress) ...[
              const SizedBox(height: 12),
              _buildSectionCard(
                title: 'shipping_address'.tr(),
                action: _canEditAddress
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: _showEditShippingAddressBottomSheet,
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        label: Text(
                          context.locale.languageCode == 'ar' ? 'تعديل عنوان التوصيل' : 'Edit Delivery Address',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      )
                    : null,
                child: Text(
                  _shippingAddress != null
                      ? _formatAddress(_shippingAddress!)
                      : (context.locale.languageCode == 'ar' ? 'لم يتم تحديد عنوان التوصيل' : 'No delivery address specified'),
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

  Widget _buildSectionCard({required Widget child, String? title, Widget? action}) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (action != null) action,
                ],
              ),
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
    final lines = <String>[];
    final name = addr['full_name'] ?? addr['recipient_name'];
    final phone = addr['phone'];
    if (name != null && name.toString().trim().isNotEmpty) {
      if (phone != null && phone.toString().trim().isNotEmpty) {
        lines.add('${name.toString().trim()} (${phone.toString().trim()})');
      } else {
        lines.add(name.toString().trim());
      }
    } else if (phone != null && phone.toString().trim().isNotEmpty) {
      lines.add(phone.toString().trim());
    }

    final locationParts = <String>[];
    if (addr['street'] != null && addr['street'].toString().trim().isNotEmpty) {
      locationParts.add(addr['street'].toString().trim());
    }
    if (addr['district'] != null && addr['district'].toString().trim().isNotEmpty) {
      locationParts.add(addr['district'].toString().trim());
    }
    if (addr['city'] != null && addr['city'].toString().trim().isNotEmpty) {
      locationParts.add(addr['city'].toString().trim());
    }
    if (addr['state'] != null && addr['state'].toString().trim().isNotEmpty) {
      locationParts.add(addr['state'].toString().trim());
    }
    if (addr['zip_code'] != null && addr['zip_code'].toString().trim().isNotEmpty) {
      locationParts.add(addr['zip_code'].toString().trim());
    }
    if (addr['country'] != null && addr['country'].toString().trim().isNotEmpty) {
      locationParts.add(addr['country'].toString().trim());
    }
    if (locationParts.isNotEmpty) {
      lines.add(locationParts.join(', '));
    }
    if (addr['notes'] != null && addr['notes'].toString().trim().isNotEmpty) {
      lines.add('${context.locale.languageCode == 'ar' ? 'ملاحظات: ' : 'Notes: '}${addr['notes'].toString().trim()}');
    }
    if (lines.isEmpty && addr['address_id'] != null) {
      return 'Address ID: ${addr['address_id']}';
    }
    return lines.isNotEmpty ? lines.join('\n') : 'N/A';
  }
}
