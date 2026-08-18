import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../../controllers/settings_controller.dart';

void showCurrencyBottomSheet(BuildContext context, [SettingsController? controller]) {
  final settingsController = controller ?? Get.find<SettingsController>();
  final lang = context.locale.languageCode;

  final currencies = [
    {
      'code': 'SAR',
      'flag': '🇸🇦',
      'title': 'saudi_riyal'.tr(),
      'symbol': lang == 'ar' ? 'ر.س • SAR' : 'SAR (SR)',
    },
    {
      'code': 'YER_OLD',
      'flag': '🇾🇪',
      'title': 'yemeni_rial_old'.tr(),
      'symbol': lang == 'ar' ? 'ر.ي (صنعاء)' : 'YER (Sana\'a)',
    },
    {
      'code': 'YER_NEW',
      'flag': '🇾🇪',
      'title': 'yemeni_rial_new'.tr(),
      'symbol': lang == 'ar' ? 'ر.ي (عدن)' : 'YER (Aden)',
    },
    {
      'code': 'USD',
      'flag': '🇺🇸',
      'title': 'us_dollar'.tr(),
      'symbol': '\$ • USD',
    },
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (bottomCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // Header icon & title
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.currency_exchange_outlined, color: Colors.teal, size: 26),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'select_currency'.tr(),
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              lang == 'ar' ? 'اختر العملة المفضلة لعرض أسعار المنتجات' : 'Select your preferred display currency',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Currency List
            ...currencies.map((curr) {
              final isSelected = settingsController.currentCurrency.value == curr['code'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () {
                    settingsController.setCurrency(curr['code']!);
                    Navigator.pop(bottomCtx);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider.withOpacity(0.6),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              curr['flag']!,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                curr['title']!,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                curr['symbol']!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isSelected ? AppColors.primary.withOpacity(0.8) : AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: Colors.white),
                          )
                        else
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.divider, width: 1.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ),
  );
}

class CurrencySwitcherAppBarButton extends StatelessWidget {
  const CurrencySwitcherAppBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Obx(() {
      final code = settingsController.currentCurrency.value;
      String flag = '🇸🇦';
      String label = 'SAR';
      if (code == 'YER_OLD') {
        flag = '🇾🇪';
        label = 'YER';
      } else if (code == 'YER_NEW') {
        flag = '🇾🇪';
        label = 'YER';
      } else if (code == 'USD') {
        flag = '🇺🇸';
        label = 'USD';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: InkWell(
          onTap: () => showCurrencyBottomSheet(context, settingsController),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider.withOpacity(0.9), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
    });
  }
}
