import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/utils/app_snackbar.dart';
import '../../../controllers/checkout_controller.dart';
import '../../address/address_list_screen.dart';

class Step1Address extends StatelessWidget {
  const Step1Address({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CheckoutController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'select_address'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'address_not_selectable'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Manage addresses button
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddressListScreen(fromCheckout: true),
                    ),
                  );
                  ctrl.loadAddresses();
                },
                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: Text(
                  'my_addresses'.tr(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  backgroundColor: AppColors.secondarySurface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        // Address list
        Expanded(
          child: Obx(() {
            if (ctrl.isLoadingAddresses.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (ctrl.addresses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 64,
                      color: AppColors.textHint,
                    ).animate().scale(duration: 500.ms),
                    const SizedBox(height: 16),
                    Text(
                      'no_addresses_yet'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'add_first_address'.tr(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AddressListScreen(fromCheckout: true),
                          ),
                        );
                        ctrl.loadAddresses();
                      },
                      icon: const Icon(Icons.add_location_alt_outlined),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ctrl.addresses.length,
              itemBuilder: (context, index) {
                final address = ctrl.addresses[index];
                return _AddressSelectCard(
                  address: address,
                  ctrl: ctrl,
                ).animate(delay: Duration(milliseconds: index * 60))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.04);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _AddressSelectCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final CheckoutController ctrl;

  const _AddressSelectCard({required this.address, required this.ctrl});

  bool get hasLocation =>
      address['lat'] != null && address['lng'] != null;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected =
          ctrl.selectedAddress.value?['id'] == address['id'];
      final canSelect = hasLocation;

      return GestureDetector(
        onTap: canSelect
            ? () => ctrl.selectedAddress.value = address
            : () => AppSnackbar.warning(context, 'address_not_selectable'.tr()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : canSelect
                      ? AppColors.divider
                      : AppColors.divider.withOpacity(0.5),
              width: isSelected ? 2 : 1.5,
            ),
            color: isSelected
                ? AppColors.primarySurface
                : canSelect
                    ? AppColors.surface
                    : AppColors.surfaceVariant.withOpacity(0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : canSelect
                              ? AppColors.border
                              : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address['label'] ?? 'Address',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: canSelect
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!canSelect)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'location_not_linked'.tr(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${address['street'] ?? ''}, ${address['city'] ?? ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: canSelect
                              ? AppColors.textSecondary
                              : AppColors.textHint,
                        ),
                      ),
                      if (address['state'] != null)
                        Text(
                          address['state'],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      if (address['phone'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 12,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              address['phone'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Location pin
                Icon(
                  hasLocation ? Icons.location_on : Icons.location_off,
                  color: hasLocation ? AppColors.success : AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
