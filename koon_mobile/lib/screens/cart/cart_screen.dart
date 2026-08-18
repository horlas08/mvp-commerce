import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../auth/login_screen.dart';
import '../checkout/checkout_screen.dart';
import '../webview/webview_screen.dart';
import '../../app/utils/url_helper.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../controllers/config_controller.dart';
import '../../app/utils/scraper_helper.dart';
import '../../services/currency_service.dart';
import '../../app/utils/currency_bottom_sheet.dart';

class CartScreen extends StatelessWidget {
  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    final cartController = Get.find<CartController>();
    final authController = Get.find<AuthController>();
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('cart'.tr()),
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                tooltip: 'back'.tr(),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          const CurrencySwitcherAppBarButton(),
          Obx(() => cartController.cartItems.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => cartController.clearCurrentCart(),
                )
              : const SizedBox()),
        ],
      ),
      body: Obx(() {
        if (!authController.isLoggedIn.value) {
          return _buildLoginPrompt(context);
        }

        return Column(
          children: [
            // Active Cart Selector (Card that opens the BottomSheet)
            Obx(() {
              final activeTypeKey = cartController.selectedCartType.value;
              final activeType = cartController.cartTypes.firstWhere(
                (type) => type['key'] == activeTypeKey,
                orElse: () => cartController.cartTypes.first,
              );
              final activeLabel = lang == 'ar' ? activeType['label_ar']! : activeType['label_en']!;
              return InkWell(
                onTap: () => _showCartTypeBottomSheet(context, cartController, lang),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(color: AppColors.divider, width: 1),
                  ),
                  child: Row(
                    children: [
                      _getStoreLogo(activeTypeKey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang == 'ar' ? 'سلة التسوق النشطة' : 'Active Shopping Cart',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              );
            }).animate().fadeIn(duration: 300.ms),

            _buildHiddenScraperWebView(cartController),

            Obx(() {
              final activeItem = cartController.currentRefreshItem.value;
              if (activeItem == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang == 'ar'
                            ? 'جاري تحديث الأسعار والمخزون في الخلفية...'
                            : 'Updating prices and stock in background...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Cart Items
            Expanded(
              child: Obx(() {
                if (cartController.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (cartController.cartItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textHint)
                            .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        Text('your_cart_is_empty'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('start_shopping'.tr(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => cartController.loadCart(autoRefresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartController.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartController.cartItems[index];
                      return _buildCartItem(item, cartController, index);
                    },
                  ),
                );
              }),
            ),

            // Bottom checkout bar
            Obx(() {
              if (cartController.cartItems.isEmpty) return const SizedBox();

              final selectedItems = cartController.cartItems.where((i) => i['is_selected'] == true).toList();
              final hasNoSelection = selectedItems.isEmpty;
              final hasUpdatingItems = selectedItems.any((i) =>
                  cartController.itemStatuses[i['id']] == 'updating' ||
                  cartController.itemStatuses[i['id']] == 'pending');
              final hasFailedItems = selectedItems.any((i) => cartController.itemStatuses[i['id']] == 'error');
              final hasStaleItems = selectedItems.any((i) {
                final extUrl = i['external_url']?.toString() ?? '';
                return extUrl.isNotEmpty && !cartController.isItemFresh(i);
              });
              final hasOutOfStock = selectedItems.any((i) {
                final rawPrice = (i['product']?['price'] ?? i['price'])?.toString() ?? '';
                final status = cartController.itemStatuses[i['id']];
                return status == 'out_of_stock' ||
                    rawPrice.toLowerCase().contains('out of stock') ||
                    rawPrice.contains('غير متوفر');
              });
              final hasUnknownPrice = selectedItems.any((i) {
                final rawPrice = (i['product']?['price'] ?? i['price'])?.toString() ?? '';
                return rawPrice.isEmpty ||
                    rawPrice.toLowerCase().contains('unknown') ||
                    KoonCurrencyService.parsePriceToDouble(rawPrice) <= 0;
              });

              final checkoutBlocked = hasNoSelection ||
                  hasUpdatingItems ||
                  hasFailedItems ||
                  hasStaleItems ||
                  hasOutOfStock ||
                  hasUnknownPrice;

              String? blockReason;
              if (hasNoSelection) {
                blockReason = lang == 'ar'
                    ? 'يرجى تحديد منتج واحد على الأقل للمتابعة.'
                    : 'Please select at least one item to proceed.';
              } else if (hasUpdatingItems) {
                blockReason = lang == 'ar'
                    ? 'يرجى الانتظار: جاري تحديث الأسعار والمخزون في الخلفية...'
                    : 'Please wait: updating prices and stock in background...';
              } else if (hasFailedItems) {
                blockReason = lang == 'ar'
                    ? 'لا يمكن إتمام الطلب: فشل تحديث السعر لبعض المنتجات. يرجى الضغط على زر إعادة المحاولة 🔄 في بطاقة المنتج.'
                    : 'Cannot proceed: price update failed for some items. Please tap retry 🔄 on the item card.';
              } else if (hasStaleItems) {
                blockReason = lang == 'ar'
                    ? 'لا يمكن إتمام الطلب: بعض المنتجات تحتاج إلى تحديث أسعارها اليومية.'
                    : 'Cannot proceed: some items require today\'s price update.';
              } else if (hasOutOfStock) {
                blockReason = lang == 'ar'
                    ? 'لا يمكن إتمام الطلب: بعض المنتجات المحددة غير متوفرة في المخزون.'
                    : 'Cannot proceed: some selected items are out of stock.';
              } else if (hasUnknownPrice) {
                blockReason = lang == 'ar'
                    ? 'لا يمكن إتمام الطلب: بعض المنتجات المحددة لا تملك سعراً معروفاً.'
                    : 'Cannot proceed: some selected items have an unknown price.';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (checkoutBlocked && blockReason != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: (hasUpdatingItems ? AppColors.primary : AppColors.error).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (hasUpdatingItems ? AppColors.primary : AppColors.error).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                hasUpdatingItems ? Icons.hourglass_top_rounded : Icons.warning_amber_rounded,
                                color: hasUpdatingItems ? AppColors.primary : AppColors.error,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  blockReason,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: hasUpdatingItems ? AppColors.primary : AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('total_amount'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 2),
                              Obx(() => Text(
                                    Get.find<SettingsController>().formatPrice(cartController.totalAmount, 'SAR'),
                                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  )),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: checkoutBlocked
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CheckoutScreen(),
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  disabledBackgroundColor: AppColors.textHint.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  'proceed_to_checkout'.tr(),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOut);
            }),
          ],
        );
      }),
      // WhatsApp FAB (commented out)
      // floatingActionButton: FloatingActionButton(
      //   mini: true,
      //   backgroundColor: const Color(0xFF25D366),
      //   onPressed: () {},
      //   child: const Icon(Icons.chat, color: Colors.white, size: 22),
      // ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, CartController controller, int index) {
    final title = item['title'] ?? item['product']?['title'] ?? 'Product';
    final double priceVal = KoonCurrencyService.parsePriceToDouble(item['product']?['price'] ?? item['price']);
    final originalCurrency = item['product']?['currency'] ?? 'SAR';
    final imageUrl = item['image_url'] ?? (item['product']?['images'] as List?)?.firstOrNull?.toString();
    final int quantity = (item['quantity'] is int)
        ? item['quantity'] as int
        : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    final int minQty = (item['min_quantity'] is int)
        ? item['min_quantity'] as int
        : int.tryParse(item['min_quantity']?.toString() ?? '1') ?? 1;
    final bool isMinOrder = quantity <= minQty;
    final settingsController = Get.find<SettingsController>();
    final externalUrl = item['external_url'] as String?;
    final cartType = item['cart_type'] ?? controller.selectedCartType.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: item['is_selected'] ?? true,
              onChanged: (v) => controller.toggleSelection(item['id'], v ?? true),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            // Clickable Image & Info (navigates back to WebView if external url exists)
            Expanded(
              child: GestureDetector(
                onTap: externalUrl != null && externalUrl.isNotEmpty
                    ? () {
                        // Parse stored selections_json so WebView can auto-select the variant.
                        Map<String, String>? preselected;
                        final rawSelections = item['selections_json'] as String?;
                        if (rawSelections != null && rawSelections.isNotEmpty) {
                          try {
                            final decoded = jsonDecode(rawSelections);
                            if (decoded is Map) {
                              preselected = decoded.map(
                                (k, v) => MapEntry(k.toString(), v.toString()),
                              );
                            }
                          } catch (_) {}
                        }
                        // Open in WebViewScreen with pre-selected variants
                        Get.to(() => WebViewScreen(
                              initialUrl: UrlHelper.convertToArabicUrl(externalUrl),
                              siteName: cartType.toString().toUpperCase(),
                              preselectedVariants: preselected,
                            ));
                      }
                    : null,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? CachedNetworkImage(imageUrl: imageUrl, width: 80, height: 80, fit: BoxFit.cover)
                          : Container(width: 80, height: 80, color: AppColors.surfaceVariant, child: const Icon(Icons.image, color: AppColors.textHint)),
                    ),
                    const SizedBox(width: 12),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ),
                              if (externalUrl != null && externalUrl.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Obx(() {
                            final status = controller.itemStatuses[item['id']];
                            final isUpdating = status == 'updating';
                            final isFailed = status == 'error';
                            final isSuccess = status == 'success';
                            final rawPriceStr = (item['product']?['price'] ?? item['price'])?.toString() ?? '';
                            final isOutOfStock = status == 'out_of_stock'
                                || rawPriceStr.toLowerCase().contains('out of stock')
                                || rawPriceStr.contains('غير متوفر');

                            // Determine what to display: formatted price, raw string, or "—"
                            String priceDisplay;
                            if (priceVal > 0) {
                              priceDisplay = settingsController.formatPrice(priceVal, originalCurrency);
                            } else if (rawPriceStr.isNotEmpty
                                && !rawPriceStr.toLowerCase().contains('unknown')
                                && !rawPriceStr.toLowerCase().contains('out of stock')
                                && !rawPriceStr.contains('غير متوفر')) {
                              // Could not parse to double — show the raw stored string as-is
                              priceDisplay = rawPriceStr;
                            } else {
                              priceDisplay = '—';
                            }

                            return Row(
                              children: [
                                if (isOutOfStock)
                                  Text(
                                    Get.locale?.languageCode == 'ar' ? 'غير متوفر' : 'Out of Stock',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error),
                                  )
                                else
                                  Text(
                                    priceDisplay,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.secondary),
                                  ),
                                if (isUpdating || isFailed || isSuccess) ...[
                                  const SizedBox(width: 8),
                                  if (isUpdating)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      ),
                                    )
                                  else if (isFailed)
                                    GestureDetector(
                                      onTap: () {
                                        final err = controller.itemErrors[item['id']] ?? (Get.locale?.languageCode == 'ar' ? 'فشل التحديث' : 'Update failed');
                                        Get.snackbar(
                                          'auto_update_error'.tr(),
                                          err,
                                          snackPosition: SnackPosition.BOTTOM,
                                          duration: const Duration(seconds: 4),
                                          mainButton: TextButton(
                                            onPressed: () => controller.retryItemRefresh(item['id']),
                                            child: Text('retry'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.error_outline, size: 12, color: AppColors.error),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () => controller.retryItemRefresh(item['id']),
                                              child: const Icon(Icons.refresh, size: 12, color: AppColors.error),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else if (isSuccess)
                                    const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                                ],
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Quantity controls
            Column(
              children: [
                _buildQtyButton(Icons.add, () => controller.updateQuantity(item['id'], quantity + 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Text('$quantity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (minQty > 1)
                        Text(
                          'min $minQty',
                          style: GoogleFonts.inter(fontSize: 9, color: AppColors.textHint, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                // Minus is disabled when quantity is already at minQty
                _buildQtyButton(
                  Icons.remove,
                  !isMinOrder
                      ? () => controller.updateQuantity(item['id'], quantity - 1)
                      : null,
                  disabled: isMinOrder,
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn(duration: 300.ms).slideX(begin: 0.05);
  }

  Widget _buildQtyButton(IconData icon, VoidCallback? onTap, {bool disabled = false}) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: disabled ? AppColors.divider.withOpacity(0.5) : AppColors.secondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: disabled ? AppColors.textHint.withOpacity(0.45) : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('login_to_continue'.tr(), style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: Text('login'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _getStoreLogo(String cartType, {double size = 32}) {
    Color logoBgColor;
    Widget logoIcon;
    
    switch (cartType) {
      case 'internal':
        logoBgColor = AppColors.primary.withOpacity(0.1);
        logoIcon = Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: size * 0.6);
        break;
      case 'amazon':
        logoBgColor = const Color(0xFFFF9900).withOpacity(0.1);
        logoIcon = Icon(Icons.storefront, color: const Color(0xFFFF9900), size: size * 0.6);
        break;
      case 'aliexpress':
        logoBgColor = const Color(0xFFFF4747).withOpacity(0.1);
        logoIcon = Icon(Icons.explore_outlined, color: const Color(0xFFFF4747), size: size * 0.6);
        break;
      case 'shein':
        logoBgColor = Colors.black.withOpacity(0.08);
        logoIcon = Icon(Icons.checkroom_outlined, color: Colors.black, size: size * 0.6);
        break;
      case 'alibaba':
        logoBgColor = const Color(0xFFFF6600).withOpacity(0.1);
        logoIcon = Icon(Icons.business_outlined, color: const Color(0xFFFF6600), size: size * 0.6);
        break;
      case 'iherb':
        logoBgColor = const Color(0xFF007943).withOpacity(0.1);
        logoIcon = Icon(Icons.eco_outlined, color: const Color(0xFF007943), size: size * 0.6);
        break;
      default:
        logoBgColor = AppColors.textHint.withOpacity(0.1);
        logoIcon = Icon(Icons.shopping_cart_outlined, color: AppColors.textHint, size: size * 0.6);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: logoBgColor,
        shape: BoxShape.circle,
      ),
      child: Center(child: logoIcon),
    );
  }

  void _showCartTypeBottomSheet(BuildContext context, CartController cartController, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: AppColors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        lang == 'ar' ? 'اختر سلة التسوق' : 'Select Shopping Cart',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceVariant,
                          padding: const EdgeInsets.all(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: cartController.cartTypes.length,
                  itemBuilder: (context, index) {
                    final type = cartController.cartTypes[index];
                    final key = type['key']!;
                    final label = lang == 'ar' ? type['label_ar']! : type['label_en']!;
                    
                    return Obx(() {
                      final isSelected = cartController.selectedCartType.value == key;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primarySurface 
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? AppColors.primary.withOpacity(0.5) 
                                : AppColors.divider,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: _getStoreLogo(key, size: 40),
                          title: Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                )
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          onTap: () {
                            cartController.selectedCartType.value = key;
                            Navigator.pop(context);
                          },
                        ),
                      );
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  },
);
}
  Widget _buildHiddenScraperWebView(CartController cartController) {
    return Obx(() {
      final currentItem = cartController.currentRefreshItem.value;
      if (currentItem == null) return const SizedBox.shrink();

      final externalUrl = currentItem['external_url']?.toString() ?? '';
      if (externalUrl.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          cartController.onRefreshFailed(currentItem['id'], reason: 'External URL is missing');
        });
        return const SizedBox.shrink();
      }

      return _HiddenScraperWebView(
        key: ValueKey(currentItem['id']),
        item: currentItem,
        controller: cartController,
      );
    });
  }
}

class _HiddenScraperWebView extends StatefulWidget {
  final Map<String, dynamic> item;
  final CartController controller;

  const _HiddenScraperWebView({
    super.key,
    required this.item,
    required this.controller,
  });

  @override
  State<_HiddenScraperWebView> createState() => _HiddenScraperWebViewState();
}

class _HiddenScraperWebViewState extends State<_HiddenScraperWebView> {
  InAppWebViewController? _webViewController;
  bool _completed = false;
  bool _injected = false;
  bool _replayed = false;

  void _finishSuccess(String price, bool isOutOfStock) {
    if (_completed || !mounted) return;
    _completed = true;
    widget.controller.onRefreshComplete(
      widget.item['id'],
      price,
      outOfStock: isOutOfStock,
    );
  }

  void _finishFailed(String reason) {
    if (_completed || !mounted) return;
    _completed = true;
    widget.controller.onRefreshFailed(
      widget.item['id'],
      reason: reason,
    );
  }

  Future<void> _injectScraper(InAppWebViewController webController, String? currentUrl) async {
    if (_completed || !mounted) return;
    try {
      final extUrl = widget.item['external_url']?.toString() ?? '';
      final targetUrl = currentUrl ?? UrlHelper.convertToArabicUrl(extUrl);
      final configController = Get.find<ConfigController>();
      final config = configController.getConfigForUrl(targetUrl) ??
          configController.getConfigForUrl(extUrl);

      if (config == null) return;

      final script = ScraperHelper.buildScraperScript(config);
      await webController.evaluateJavascript(source: script);

      // Replay stored variant selections if present
      final rawSelections = widget.item['selections_json'] as String?;
      if (rawSelections != null && rawSelections.isNotEmpty && !_replayed) {
        _replayed = true;
        try {
          final decoded = jsonDecode(rawSelections);
          if (decoded is Map && decoded.isNotEmpty) {
            Get.log('[CartScraper] Replaying variants for ${widget.item['id']}: $decoded');
            await webController.evaluateJavascript(
              source: 'window.__koonOpenSkuPicker && window.__koonOpenSkuPicker()',
            );
            await Future.delayed(const Duration(milliseconds: 350));
            for (final entry in decoded.entries) {
              if (_completed || !mounted) return;
              final name = entry.key.toString();
              final value = entry.value.toString();
              final js = 'window.__koonSelectOption ? window.__koonSelectOption(${jsonEncode(name)}, ${jsonEncode(value)}) : false';
              await webController.evaluateJavascript(source: js);
              await Future.delayed(const Duration(milliseconds: 450));
            }
          }
        } catch (e) {
          Get.log('[CartScraper] Variant replay error: $e');
        }
      }

      // Attempt immediate extraction
      if (!_completed && mounted) {
        final raw = await webController.evaluateJavascript(
          source: 'window.__koonExtractProduct ? window.__koonExtractProduct() : null',
        );
        if (raw != null && raw is Map) {
          _handleExtractedData(Map<String, dynamic>.from(raw));
        }
      }
    } catch (e) {
      Get.log('[CartScraper] Scraper injection exception: $e');
    }
  }

  void _handleExtractedData(Map<String, dynamic> data) {
    if (_completed || !mounted) return;
    final price = data['price']?.toString() ?? '';
    final isOutOfStock = data['is_out_of_stock'] == true ||
        price.toLowerCase().contains('out of stock') ||
        price.contains('غير متوفر');

    if (isOutOfStock) {
      Get.log('[CartScraper] Extracted out-of-stock for ${widget.item['id']}');
      _finishSuccess(price, true);
    } else if (price.isNotEmpty &&
        !price.toLowerCase().contains('unknown') &&
        KoonCurrencyService.parsePriceToDouble(price) > 0) {
      Get.log('[CartScraper] Extracted valid price "$price" for ${widget.item['id']}');
      _finishSuccess(price, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final externalUrl = widget.item['external_url']?.toString() ?? '';
    final targetUrl = UrlHelper.convertToArabicUrl(externalUrl);

    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 375,
        height: 667,
        child: InAppWebView(
          key: ValueKey('${widget.item['id']}_$targetUrl'),
          initialUrlRequest: URLRequest(
            url: WebUri(targetUrl),
            headers: {
              'Accept-Language': 'ar-SA,ar;q=0.9,en-US;q=0.8,en;q=0.7',
            },
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            cacheEnabled: true,
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            userAgent:
                "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
          ),
          onWebViewCreated: (controller) async {
            _webViewController = controller;
            controller.addJavaScriptHandler(
              handlerName: 'onProductDetected',
              callback: (args) {
                if (_completed || !mounted) return;
                if (args.isNotEmpty && args[0] != null && args[0] is Map) {
                  final data = Map<String, dynamic>.from(args[0]);
                  _handleExtractedData(data);
                }
              },
            );
            await WebViewScreen.setupCurrencyCookies(targetUrl);
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;
            final scheme = uri.scheme.toLowerCase();
            const allowedSchemes = {'http', 'https', 'about', 'data', 'blank'};
            if (!allowedSchemes.contains(scheme)) {
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame ?? true) {
              Get.log('[CartScraper] Mainframe error: ${error.description}');
              if (error.type == -2 || error.description.contains('ERR_NAME_NOT_RESOLVED')) {
                _finishFailed('Network error: ${error.description}');
              }
            }
          },
          onReceivedHttpError: (controller, request, errorResponse) {
            if (request.isForMainFrame ?? true) {
              final code = errorResponse.statusCode;
              if (code != null && code >= 400 && code != 403) {
                Get.log('[CartScraper] HTTP error $code');
                _finishFailed('HTTP $code error from server');
              }
            }
          },
          onProgressChanged: (controller, progress) {
            if (progress >= 50 && !_injected) {
              _injected = true;
              _injectScraper(controller, null);
            }
          },
          onPageCommitVisible: (controller, url) {
            if (!_injected) {
              _injected = true;
              _injectScraper(controller, url?.toString());
            }
          },
          onLoadStop: (controller, url) async {
            Get.log('[CartScraper] Page onLoadStop: $url');
            await WebViewScreen.setupCurrencyCookies(url?.toString() ?? targetUrl);
            await _injectScraper(controller, url?.toString());

            // Delayed fallback extraction if not completed yet
            if (!_completed) {
              await Future.delayed(const Duration(milliseconds: 1500));
              if (!_completed && mounted) {
                await _injectScraper(controller, url?.toString());
              }
            }
          },
        ),
      ),
    );
  }
}
