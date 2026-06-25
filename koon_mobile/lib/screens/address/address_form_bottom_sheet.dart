import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/address_controller.dart';

/// Bottom sheet for adding or editing an address.
/// Pass [existingAddress] to pre-fill the form for editing.
class AddressFormBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? existingAddress;

  const AddressFormBottomSheet({super.key, this.existingAddress});

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? existingAddress,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressFormBottomSheet(existingAddress: existingAddress),
    );
  }

  @override
  State<AddressFormBottomSheet> createState() => _AddressFormBottomSheetState();
}

class _AddressFormBottomSheetState extends State<AddressFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _phoneCtrl;

  late final AddressController _ctrl;
  bool get isEditing => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<AddressController>();
    final addr = widget.existingAddress;
    _labelCtrl = TextEditingController(text: addr?['label'] ?? '');
    _streetCtrl = TextEditingController(text: addr?['street'] ?? '');
    _phoneCtrl = TextEditingController(text: addr?['phone'] ?? '');

    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.prefillForEdit(addr!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ctrl.resetForm();
      });
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    bool success;
    if (isEditing) {
      success = await _ctrl.updateAddress(
        addressId: widget.existingAddress!['id'].toString(),
        label: _labelCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
    } else {
      success = await _ctrl.addAddress(
        label: _labelCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
    }

    if (success) {
      Navigator.of(context).pop(true);
      Get.snackbar(
        'success'.tr(),
        isEditing ? 'address_updated'.tr() : 'address_added'.tr(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'edit_address'.tr() : 'add_address'.tr(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(
                        controller: _labelCtrl,
                        label: 'address_label'.tr(),
                        icon: Icons.label_outline,
                        validator: (v) =>
                            v!.isEmpty ? 'name_is_required'.tr() : null,
                      ),
                      const SizedBox(height: 14),
                      // State dropdown
                      Obx(() {
                        if (_ctrl.isLoadingStates.value) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        return _buildDropdown(
                          label: 'select_state'.tr(),
                          icon: Icons.map_outlined,
                          value: _ctrl.selectedState.value,
                          items: _ctrl.states,
                          onChanged: (v) => _ctrl.onStateChanged(v),
                          displayKey: 'name',
                        );
                      }),
                      const SizedBox(height: 14),
                      // City dropdown
                      Obx(() {
                        if (_ctrl.isLoadingCities.value) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        return _buildDropdown(
                          label: 'select_city'.tr(),
                          icon: Icons.location_city_outlined,
                          value: _ctrl.selectedCity.value,
                          items: _ctrl.cities,
                          onChanged: _ctrl.selectedState.value == null
                              ? null
                              : (v) {
                                  _ctrl.selectedCity.value = v;
                                },
                          displayKey: 'name',
                        );
                      }),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _streetCtrl,
                        label: 'street_address'.tr(),
                        icon: Icons.home_outlined,
                        validator: (v) =>
                            v!.isEmpty ? 'name_is_required'.tr() : null,
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _phoneCtrl,
                        label: 'phone'.tr(),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v!.isEmpty ? 'name_is_required'.tr() : null,
                      ),
                      const SizedBox(height: 24),
                      // Submit
                      Obx(() => SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _ctrl.isSaving.value ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _ctrl.isSaving.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'save'.tr(),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          )),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required Map<String, dynamic>? value,
    required List<Map<String, dynamic>> items,
    required void Function(Map<String, dynamic>?)? onChanged,
    required String displayKey,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: value,
                hint: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item[displayKey]?.toString() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
