import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../services/seller_service.dart';

class BecomeSellerScreen extends StatefulWidget {
  const BecomeSellerScreen({super.key});

  @override
  State<BecomeSellerScreen> createState() => _BecomeSellerScreenState();
}

class _BecomeSellerScreenState extends State<BecomeSellerScreen> {
  final SellerService _sellerService = SellerService();
  final _formKey = GlobalKey<FormState>();
  
  final _nameEnCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _descEnCtrl = TextEditingController();
  final _descArCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameArCtrl.dispose();
    _descEnCtrl.dispose();
    _descArCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final response = await _sellerService.applyAsSeller(
      storeNameEn: _nameEnCtrl.text.trim(),
      storeNameAr: _nameArCtrl.text.trim(),
      descriptionEn: _descEnCtrl.text.trim().isEmpty ? null : _descEnCtrl.text.trim(),
      descriptionAr: _descArCtrl.text.trim().isEmpty ? null : _descArCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim().isEmpty ? null : _logoUrlCtrl.text.trim(),
    );

    setState(() => _isLoading = false);
    if (response != null) {
      Get.snackbar('Success', 'Application submitted successfully!'.tr(), snackPosition: SnackPosition.BOTTOM);
      Navigator.pop(context);
    } else {
      Get.snackbar('Error', 'Failed to submit application'.tr(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('be_a_seller'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Apply to Become a Seller'.tr(),
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Open your shop and start selling internal products directly on Koon.'.tr(),
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _nameEnCtrl,
                      decoration: InputDecoration(
                        labelText: 'Store Name (English)'.tr(),
                        prefixIcon: const Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameArCtrl,
                      decoration: InputDecoration(
                        labelText: 'Store Name (Arabic)'.tr(),
                        prefixIcon: const Icon(Icons.storefront),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descEnCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Store Description (English)'.tr(),
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descArCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Store Description (Arabic)'.tr(),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _logoUrlCtrl,
                      decoration: InputDecoration(
                        labelText: 'Store Logo URL'.tr(),
                        prefixIcon: const Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Submit Application'.tr(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
