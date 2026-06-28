import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../app/utils/app_snackbar.dart';
import '../../services/address_service.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final AddressService _addressService = AddressService();
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final data = await _addressService.getAddresses();
    setState(() {
      _addresses = data;
      _isLoading = false;
    });
  }

  Future<void> _deleteAddress(String id) async {
    final success = await _addressService.deleteAddress(id);
    if (success) {
      AppSnackbar.success(context, 'address_deleted'.tr());
      _loadAddresses();
    }
  }

  void _showAddAddressDialog() {
    final formKey = GlobalKey<FormState>();
    final labelCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    bool isDefault = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add New Address'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: labelCtrl,
                    decoration: InputDecoration(labelText: 'Label (e.g. Home, Work)'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: 'Full Name'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(labelText: 'Phone'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: streetCtrl,
                    decoration: InputDecoration(labelText: 'Street Address'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cityCtrl,
                    decoration: InputDecoration(labelText: 'City'.tr()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('Set as Default Address'.tr()),
                    value: isDefault,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setModalState(() => isDefault = val),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      await _addressService.addAddress(
                        label: labelCtrl.text.trim(),
                        fullName: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        street: streetCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        isDefault: isDefault,
                      );
                      _loadAddresses();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Add Address'.tr(), style: const TextStyle(color: Colors.white)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Addresses'.tr(), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text('No addresses found'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    final isDefault = addr['is_default'] ?? false;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isDefault ? const BorderSide(color: AppColors.primary, width: 1.5) : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Row(
                          children: [
                            Text(addr['label'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(width: 8),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                                child: Text('Default'.tr(), style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(addr['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              Text(addr['phone'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                              Text('${addr['street']}, ${addr['city']}', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _deleteAddress(addr['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAddAddressDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
