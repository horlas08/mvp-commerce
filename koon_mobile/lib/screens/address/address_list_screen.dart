import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/address_controller.dart';
import 'address_form_bottom_sheet.dart';
import 'map_picker_screen.dart';

class AddressListScreen extends StatelessWidget {
  /// Whether we're coming from checkout (shows "Back to Checkout" button)
  final bool fromCheckout;

  const AddressListScreen({super.key, this.fromCheckout = false});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AddressController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'my_addresses'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: fromCheckout ? 'back_to_checkout'.tr() : 'back'.tr(),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: () => AddressFormBottomSheet.show(context),
            tooltip: 'add_address'.tr(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (ctrl.addresses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 20),
                Text(
                  'no_addresses_yet'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'add_first_address'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => AddressFormBottomSheet.show(context),
                  icon: const Icon(Icons.add),
                  label: Text('add_address'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ctrl.addresses.length,
          itemBuilder: (context, index) {
            final address = ctrl.addresses[index];
            return _AddressCard(
              address: address,
              ctrl: ctrl,
            ).animate(delay: Duration(milliseconds: index * 60))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.04);
          },
        );
      }),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final AddressController ctrl;

  const _AddressCard({required this.address, required this.ctrl});

  bool get hasLocation =>
      address['lat'] != null && address['lng'] != null;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasLocation
                ? AppColors.success.withOpacity(0.4)
                : AppColors.divider,
            width: 1.5,
          ),
          color: AppColors.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasLocation
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasLocation
                          ? Icons.location_on
                          : Icons.location_off_outlined,
                      color: hasLocation
                          ? AppColors.success
                          : AppColors.textHint,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address['label'] ?? 'Address',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (address['phone'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            address['phone'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Edit & Delete
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await AddressFormBottomSheet.show(
                          context,
                          existingAddress: address,
                        );
                      } else if (action == 'delete') {
                        _confirmDelete(context);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text('edit_address'.tr()),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'delete'.tr(),
                              style:
                                  const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Location status + link button
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasLocation
                            ? AppColors.success.withOpacity(0.08)
                            : AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasLocation
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 14,
                            color: hasLocation
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasLocation
                                  ? 'location_linked'.tr()
                                  : 'location_not_linked'.tr(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasLocation
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapPickerScreen(
                            addressId: address['id'].toString(),
                            addressLabel:
                                address['label'] ?? 'Address',
                            initialLat: address['lat']?.toDouble(),
                            initialLng: address['lng']?.toDouble(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    label: Text(
                      'link_location'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      backgroundColor:
                          AppColors.secondarySurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'delete_address_confirm'.tr(),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'delete_address_desc'.tr(),
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ctrl.deleteAddress(address['id'].toString());
              Get.snackbar(
                'success'.tr(),
                'address_deleted'.tr(),
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.success,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'delete'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
