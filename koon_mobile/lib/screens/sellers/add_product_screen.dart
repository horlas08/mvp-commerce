import 'package:flutter/material.dart' hide TextDirection;
import 'dart:ui' show TextDirection;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../services/seller_service.dart';
import '../../services/api_service.dart';
import '../../app/constants/api_constants.dart';

class AddProductScreen extends StatefulWidget {
  /// Pass an existing product map to enable edit mode.
  final Map<String, dynamic>? product;

  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final SellerService _sellerService = SellerService();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // ── Basic Info ──────────────────────────────────────────────────────────
  final _titleEnCtrl = TextEditingController();
  final _titleArCtrl = TextEditingController();
  final _descEnCtrl = TextEditingController();
  final _descArCtrl = TextEditingController();

  // ── Images (up to 6) ────────────────────────────────────────────────────
  final List<TextEditingController> _imageControllers =
      List.generate(6, (_) => TextEditingController());

  // ── Category ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _categoriesLoading = false;

  // ── Pricing ─────────────────────────────────────────────────────────────
  final _priceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  String _currency = 'SAR';

  static const List<String> _currencies = ['SAR', 'USD', 'EUR', 'AED', 'KWD', 'BHD', 'QAR'];

  // ── Stock ───────────────────────────────────────────────────────────────
  final _stockCtrl = TextEditingController();

  // ── Variants ────────────────────────────────────────────────────────────
  // Each variant type: { name: String, options: [ { name, stock, price } ] }
  final List<Map<String, dynamic>> _variantTypes = [];
  bool _variantsExpanded = false;

  // ── Shipping ────────────────────────────────────────────────────────────
  final _weightCtrl = TextEditingController();
  final _deliveryDaysCtrl = TextEditingController();

  // ── Status ──────────────────────────────────────────────────────────────
  bool _isActive = true;

  bool get _isEditMode => widget.product != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditMode) _populateFields();
  }

  @override
  void dispose() {
    _titleEnCtrl.dispose();
    _titleArCtrl.dispose();
    _descEnCtrl.dispose();
    _descArCtrl.dispose();
    for (final c in _imageControllers) {
      c.dispose();
    }
    _priceCtrl.dispose();
    _discountPriceCtrl.dispose();
    _stockCtrl.dispose();
    _weightCtrl.dispose();
    _deliveryDaysCtrl.dispose();
    super.dispose();
  }

  void _populateFields() {
    final p = widget.product!;
    _titleEnCtrl.text = p['title_en'] ?? p['title'] ?? '';
    _titleArCtrl.text = p['title_ar'] ?? '';
    _descEnCtrl.text = p['description_en'] ?? p['description'] ?? '';
    _descArCtrl.text = p['description_ar'] ?? '';

    final images = p['images'] as List? ?? [];
    for (int i = 0; i < images.length && i < 6; i++) {
      _imageControllers[i].text = images[i]?.toString() ?? '';
    }

    _selectedCategoryId = p['category_id']?.toString();
    _priceCtrl.text = (p['price'] ?? '').toString();
    _discountPriceCtrl.text = (p['discount_price'] ?? '').toString();
    _currency = p['currency'] ?? 'SAR';
    _stockCtrl.text = (p['stock_quantity'] ?? '').toString();
    _weightCtrl.text = (p['weight_kg'] ?? '').toString();
    _deliveryDaysCtrl.text = (p['estimated_delivery_days'] ?? '').toString();
    _isActive = p['is_active'] != false;

    // Variants
    final variants = p['variants'] as List? ?? [];
    for (final v in variants) {
      _variantTypes.add({
        'nameCtrl': TextEditingController(text: v['type'] ?? v['name'] ?? ''),
        'options': ((v['options'] as List?) ?? []).map((o) {
          return {
            'nameCtrl': TextEditingController(text: o['name'] ?? ''),
            'stockCtrl': TextEditingController(text: (o['stock'] ?? '').toString()),
            'priceCtrl': TextEditingController(text: (o['price'] ?? '').toString()),
          };
        }).toList(),
      });
    }
    if (_variantTypes.isNotEmpty) _variantsExpanded = true;
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final lang = context.locale.languageCode;
      final dio = ApiService().dio;
      final res = await dio.get(ApiConstants.categories, queryParameters: {'lang': lang});
      if (res.statusCode == 200) {
        _categories = List<Map<String, dynamic>>.from(res.data);
      }
    } catch (_) {}
    if (mounted) setState(() => _categoriesLoading = false);
  }

  void _addVariantType() {
    setState(() {
      _variantTypes.add({
        'nameCtrl': TextEditingController(),
        'options': <Map<String, dynamic>>[],
      });
      _variantsExpanded = true;
    });
  }

  void _removeVariantType(int index) {
    final vt = _variantTypes[index];
    (vt['nameCtrl'] as TextEditingController).dispose();
    for (final opt in (vt['options'] as List)) {
      (opt['nameCtrl'] as TextEditingController).dispose();
      (opt['stockCtrl'] as TextEditingController).dispose();
      (opt['priceCtrl'] as TextEditingController).dispose();
    }
    setState(() => _variantTypes.removeAt(index));
  }

  void _addVariantOption(int variantIndex) {
    setState(() {
      (_variantTypes[variantIndex]['options'] as List).add({
        'nameCtrl': TextEditingController(),
        'stockCtrl': TextEditingController(),
        'priceCtrl': TextEditingController(),
      });
    });
  }

  void _removeVariantOption(int variantIndex, int optionIndex) {
    final opts = _variantTypes[variantIndex]['options'] as List;
    final opt = opts[optionIndex];
    (opt['nameCtrl'] as TextEditingController).dispose();
    (opt['stockCtrl'] as TextEditingController).dispose();
    (opt['priceCtrl'] as TextEditingController).dispose();
    setState(() => opts.removeAt(optionIndex));
  }

  Map<String, dynamic> _buildPayload() {
    final images = _imageControllers
        .map((c) => c.text.trim())
        .where((url) => url.isNotEmpty)
        .toList();

    final variants = _variantTypes.map((vt) {
      final opts = (vt['options'] as List).map((o) {
        return {
          'name': (o['nameCtrl'] as TextEditingController).text.trim(),
          if ((o['stockCtrl'] as TextEditingController).text.trim().isNotEmpty)
            'stock': int.tryParse((o['stockCtrl'] as TextEditingController).text.trim()),
          if ((o['priceCtrl'] as TextEditingController).text.trim().isNotEmpty)
            'price': double.tryParse((o['priceCtrl'] as TextEditingController).text.trim()),
        };
      }).toList();
      return {
        'name': (vt['nameCtrl'] as TextEditingController).text.trim(),
        'options': opts,
      };
    }).toList();

    return {
      'title_en': _titleEnCtrl.text.trim(),
      'title_ar': _titleArCtrl.text.trim(),
      if (_descEnCtrl.text.trim().isNotEmpty) 'description_en': _descEnCtrl.text.trim(),
      if (_descArCtrl.text.trim().isNotEmpty) 'description_ar': _descArCtrl.text.trim(),
      'images': images,
      if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      if (_discountPriceCtrl.text.trim().isNotEmpty)
        'discount_price': double.tryParse(_discountPriceCtrl.text.trim()),
      'currency': _currency,
      if (_stockCtrl.text.trim().isNotEmpty)
        'stock_quantity': int.tryParse(_stockCtrl.text.trim()),
      if (variants.isNotEmpty) 'variants': variants,
      if (_weightCtrl.text.trim().isNotEmpty)
        'weight_kg': double.tryParse(_weightCtrl.text.trim()),
      if (_deliveryDaysCtrl.text.trim().isNotEmpty)
        'estimated_delivery_days': int.tryParse(_deliveryDaysCtrl.text.trim()),
      'is_active': _isActive,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = _buildPayload();
    Map<String, dynamic>? result;

    if (_isEditMode) {
      final productId = widget.product!['id']?.toString() ?? '';
      result = await _sellerService.updateProduct(productId, payload);
    } else {
      result = await _sellerService.createProduct(payload);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'product_updated'.tr() : 'product_created'.tr(),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_occurred'.tr(), style: GoogleFonts.inter()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          _isEditMode ? 'edit_product'.tr() : 'add_product'.tr(),
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 1. Basic Info ──────────────────────────────────────────
            _buildSectionHeader('📦', 'basic_information'.tr()),
            _buildCard(
              children: [
                _buildTextField(
                  controller: _titleEnCtrl,
                  label: 'title_en'.tr(),
                  hint: 'enter_title_en'.tr(),
                  required: true,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _titleArCtrl,
                  label: 'title_ar'.tr(),
                  hint: 'enter_title_ar'.tr(),
                  textDirection: TextDirection.rtl,
                  required: true,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _descEnCtrl,
                  label: 'description_en'.tr(),
                  hint: 'enter_desc_en'.tr(),
                  maxLines: 4,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _descArCtrl,
                  label: 'description_ar'.tr(),
                  hint: 'enter_desc_ar'.tr(),
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ).animate().fadeIn(duration: 350.ms),

            const SizedBox(height: 20),

            // ── 2. Images ──────────────────────────────────────────────
            _buildSectionHeader('🖼️', 'images'.tr()),
            _buildCard(
              children: List.generate(6, (i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: i < 5 ? 14 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: _imageControllers[i],
                        label: '${'image'.tr()} ${i + 1}',
                        hint: 'https://...',
                        keyboardType: TextInputType.url,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_imageControllers[i].text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: _imageControllers[i].text.trim(),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 120,
                                color: AppColors.surfaceVariant,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 60,
                                color: AppColors.surfaceVariant,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image_outlined, color: AppColors.textHint),
                                    SizedBox(width: 8),
                                    Text('Invalid URL', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ).animate().fadeIn(duration: 350.ms, delay: 50.ms),

            const SizedBox(height: 20),

            // ── 3. Category ────────────────────────────────────────────
            _buildSectionHeader('🏷️', 'category'.tr()),
            _buildCard(
              children: [
                _categoriesLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                    : DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: _inputDecoration('select_category'.tr()),
                        isExpanded: true,
                        items: _categories.map((cat) {
                          final nameEn = cat['name_en'] ?? cat['name'] ?? '';
                          final nameAr = cat['name_ar'] ?? '';
                          final id = cat['id']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              nameAr.isNotEmpty ? '$nameEn / $nameAr' : nameEn,
                              style: GoogleFonts.inter(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCategoryId = val),
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                        dropdownColor: AppColors.surface,
                      ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 100.ms),

            const SizedBox(height: 20),

            // ── 4. Pricing ─────────────────────────────────────────────
            _buildSectionHeader('💰', 'pricing'.tr()),
            _buildCard(
              children: [
                _buildTextField(
                  controller: _priceCtrl,
                  label: 'price'.tr(),
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  required: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'required_field'.tr();
                    if (double.tryParse(v.trim()) == null) return 'invalid_number'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _discountPriceCtrl,
                  label: 'discount_price'.tr(),
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && double.tryParse(v.trim()) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: _inputDecoration('currency'.tr()),
                  items: _currencies
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: GoogleFonts.inter(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _currency = val ?? 'SAR'),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                  dropdownColor: AppColors.surface,
                ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

            const SizedBox(height: 20),

            // ── 5. Stock ───────────────────────────────────────────────
            _buildSectionHeader('📊', 'stock'.tr()),
            _buildCard(
              children: [
                _buildTextField(
                  controller: _stockCtrl,
                  label: 'stock_quantity'.tr(),
                  hint: '0',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 200.ms),

            const SizedBox(height: 20),

            // ── 6. Variants ────────────────────────────────────────────
            _buildSectionHeader('🎨', 'variants'.tr()),
            _buildCard(
              children: [
                ExpansionTile(
                  initiallyExpanded: _variantsExpanded,
                  onExpansionChanged: (v) => setState(() => _variantsExpanded = v),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'variants_optional'.tr(),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    'variants_hint'.tr(),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  children: [
                    const SizedBox(height: 8),
                    ..._variantTypes.asMap().entries.map((entry) {
                      final vi = entry.key;
                      final vt = entry.value;
                      return _buildVariantTypeCard(vi, vt);
                    }),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addVariantType,
                      icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                      label: Text(
                        'add_variant_type'.tr(),
                        style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 250.ms),

            const SizedBox(height: 20),

            // ── 7. Shipping ────────────────────────────────────────────
            _buildSectionHeader('🚚', 'shipping'.tr()),
            _buildCard(
              children: [
                _buildTextField(
                  controller: _weightCtrl,
                  label: 'weight_kg'.tr(),
                  hint: '0.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && double.tryParse(v.trim()) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  controller: _deliveryDaysCtrl,
                  label: 'estimated_delivery_days'.tr(),
                  hint: '3',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && int.tryParse(v.trim()) == null) {
                      return 'invalid_number'.tr();
                    }
                    return null;
                  },
                ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 300.ms),

            const SizedBox(height: 20),

            // ── 8. Status ──────────────────────────────────────────────
            _buildSectionHeader('⚡', 'status'.tr()),
            _buildCard(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isActive ? 'active'.tr() : 'draft'.tr(),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _isActive ? 'product_visible'.tr() : 'product_hidden'.tr(),
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 350.ms),

            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _isEditMode ? 'save_changes'.tr() : 'publish_product'.tr(),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 400.ms),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Helper Widgets
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextDirection? textDirection,
    bool required = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textDirection: textDirection,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      decoration: _inputDecoration(label, hint: hint),
      validator: validator ??
          (required
              ? (v) {
                  if (v == null || v.trim().isEmpty) return 'required_field'.tr();
                  return null;
                }
              : null),
    );
  }

  Widget _buildVariantTypeCard(int vi, Map<String, dynamic> vt) {
    final options = vt['options'] as List<Map<String, dynamic>>;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: vt['nameCtrl'] as TextEditingController,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _inputDecoration('variant_type_name'.tr(), hint: 'e.g. Size, Color'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _removeVariantType(vi),
                tooltip: 'remove'.tr(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((oe) {
            final oi = oe.key;
            final opt = oe.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: opt['nameCtrl'] as TextEditingController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDecoration('option_name'.tr(), hint: 'e.g. M, Red'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: opt['stockCtrl'] as TextEditingController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDecoration('stock'.tr(), hint: '0'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: opt['priceCtrl'] as TextEditingController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDecoration('price'.tr(), hint: '0.00'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                    onPressed: () => _removeVariantOption(vi, oi),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => _addVariantOption(vi),
            icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
            label: Text(
              'add_option'.tr(),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }
}

