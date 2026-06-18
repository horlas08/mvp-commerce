import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/compare_controller.dart';
import '../../services/seller_service.dart';
import '../auth/login_screen.dart';

// Import sub-screens
import 'edit_profile_screen.dart';
import 'addresses_screen.dart';
import 'wishlist_screen.dart';
import 'refund_requests_screen.dart';
import 'coupons_screen.dart';
import 'become_seller_screen.dart';
import 'my_credit_screen.dart';
import 'compare_list_screen.dart';
import '../sellers/seller_shop_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final settingsController = Get.find<SettingsController>();
    final compareController = Get.find<CompareController>();
    final sellerService = SellerService();

    return Scaffold(
      body: Obx(() {
        final user = authController.user.value;
        final isLoggedIn = authController.isLoggedIn.value;
        final isSeller = user?['role'] == 'seller';

        return CustomScrollView(
          slivers: [
            // Premium Header with Orange Gradient
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: isLoggedIn && authController.userAvatar.isNotEmpty
                              ? ClipOval(child: Image.network(authController.userAvatar, fit: BoxFit.cover))
                              : const Icon(Icons.person, color: AppColors.primary, size: 40),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLoggedIn) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        authController.userName,
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSeller)
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Store Owner'.tr(),
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  authController.userEmail,
                                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                Text(
                                  'Welcome Guest'.tr(),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'login'.tr(),
                                      style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Profile Sections List
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // Account Settings Card
                  _buildSectionHeader('My Account'.tr()),
                  _buildCardContainer([
                    _buildSettingsTile(
                      icon: Icons.edit_outlined,
                      iconColor: AppColors.primary,
                      title: 'edit_profile'.tr(),
                      onTap: () => _checkAndNavigate(context, isLoggedIn, const EditProfileScreen()),
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.location_on_outlined,
                      iconColor: AppColors.primary,
                      title: 'addresses'.tr(),
                      onTap: () => _checkAndNavigate(context, isLoggedIn, const AddressesScreen()),
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.credit_card_outlined,
                      iconColor: AppColors.primary,
                      title: 'my_credit'.tr(),
                      trailingText: isLoggedIn ? '${authController.userCredit.toStringAsFixed(2)} SAR' : null,
                      onTap: () => _checkAndNavigate(context, isLoggedIn, const MyCreditScreen()),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // E-Commerce Features Card
                  _buildSectionHeader('Features'.tr()),
                  _buildCardContainer([
                    _buildSettingsTile(
                      icon: Icons.favorite_outline,
                      iconColor: AppColors.secondary,
                      title: 'my_wishlist'.tr(),
                      onTap: () => _checkAndNavigate(context, isLoggedIn, const WishlistScreen()),
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.compare_arrows_outlined,
                      iconColor: AppColors.secondary,
                      title: 'compare_list'.tr(),
                      trailingText: '${compareController.comparedProducts.length}',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompareListScreen())),
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.local_offer_outlined,
                      iconColor: AppColors.secondary,
                      title: 'coupons'.tr(),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CouponsScreen())),
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.money_off_outlined,
                      iconColor: AppColors.secondary,
                      title: 'refund_requests'.tr(),
                      onTap: () => _checkAndNavigate(context, isLoggedIn, const RefundRequestsScreen()),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // App Preferences Card
                  _buildSectionHeader('Preferences'.tr()),
                  _buildCardContainer([
                    _buildSettingsTile(
                      icon: Icons.translate_outlined,
                      iconColor: Colors.teal,
                      title: 'language'.tr(),
                      trailingText: context.locale.languageCode == 'en' ? 'English' : 'العربية',
                      onTap: () async {
                        final currentLocale = context.locale;
                        if (currentLocale.languageCode == 'en') {
                          await context.setLocale(const Locale('ar'));
                          Get.updateLocale(const Locale('ar'));
                        } else {
                          await context.setLocale(const Locale('en'));
                          Get.updateLocale(const Locale('en'));
                        }
                      },
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.currency_exchange_outlined,
                      iconColor: Colors.teal,
                      title: 'currency'.tr(),
                      trailingText: settingsController.currentCurrency.value,
                      onTap: () => _showCurrencySelector(context, settingsController),
                    ),
                    _buildDivider(),
                    ThemeSwitcher(
                      builder: (context) {
                        return SwitchListTile(
                          value: settingsController.isDarkMode.value,
                          onChanged: (_) {
                            final isDarkNow = settingsController.isDarkMode.value;
                            final nextTheme = isDarkNow ? AppTheme.lightTheme : AppTheme.darkTheme;
                            ThemeSwitcher.of(context).changeTheme(theme: nextTheme);
                            settingsController.toggleTheme();
                          },
                          title: Text('dark_mode'.tr(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          secondary: const Icon(Icons.dark_mode_outlined, color: Colors.teal),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          activeColor: AppColors.primary,
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Sellers card
                  _buildSectionHeader('explore'.tr()),
                  _buildCardContainer([
                    _buildSettingsTile(
                      icon: Icons.storefront_outlined,
                      iconColor: Colors.deepPurple,
                      title: 'browse_all_sellers'.tr(),
                      onTap: () => _showSellersDialog(context, sellerService),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Become Seller Banner or Dashboard Card
                  if (isLoggedIn) ...[
                    if (isSeller)
                      _buildSellerDashboardCard(context, user!)
                    else
                      _buildBecomeSellerPromoCard(context),
                    const SizedBox(height: 32),
                  ],

                  // Logout button
                  if (isLoggedIn)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => authController.logout(),
                          icon: const Icon(Icons.logout, color: AppColors.error),
                          label: Text('logout'.tr(), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _checkAndNavigate(BuildContext context, bool isLoggedIn, Widget screen) {
    if (!isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Get.theme.dividerColor, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: children,
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }

  Widget _buildBecomeSellerPromoCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Be a Seller'.tr(),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Start selling your products directly on Koon and reach thousands of buyers.'.tr(),
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BecomeSellerScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Apply Now'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05);
  }

  Widget _buildSellerDashboardCard(BuildContext context, Map<String, dynamic> user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.secondaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.secondary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_outlined, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(
                'Seller Dashboard'.tr(),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your store listings, view customer orders, and track your shop performance.'.tr(),
            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _showSellerDashboardDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Manage Shop'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05);
  }

  void _showSellerDashboardDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: AppColors.secondary, size: 28),
                const SizedBox(width: 12),
                Text('Store Dashboard'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 24),
            _buildDashboardRow(Icons.shopping_bag_outlined, 'Total Products'.tr(), '12'),
            const SizedBox(height: 16),
            _buildDashboardRow(Icons.receipt_long_outlined, 'Pending Orders'.tr(), '3'),
            const SizedBox(height: 16),
            _buildDashboardRow(Icons.monetization_on_outlined, 'Monthly Sales'.tr(), '1,840.00 SAR'),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              child: Text('Close'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  void _showCurrencySelector(BuildContext context, SettingsController settingsController) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Select Currency'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Saudi Riyal (SAR)'),
              trailing: settingsController.currentCurrency.value == 'SAR' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                settingsController.setCurrency('SAR');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('US Dollar (USD)'),
              trailing: settingsController.currentCurrency.value == 'USD' ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                settingsController.setCurrency('USD');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSellersDialog(BuildContext context, SellerService sellerService) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: sellerService.getSellers(lang: context.locale.languageCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }

            final sellers = snapshot.data ?? [];
            if (sellers.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('No registered sellers found'.tr(), style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Registered Sellers'.tr(), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sellers.length,
                      itemBuilder: (context, index) {
                        final seller = sellers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primarySurface,
                            backgroundImage: seller['logo_url'] != null ? NetworkImage(seller['logo_url']) : null,
                            child: seller['logo_url'] == null ? const Icon(Icons.storefront, color: AppColors.primary) : null,
                          ),
                          title: Text(seller['store_name'] ?? ''),
                          subtitle: Text(seller['description'] ?? 'No description'.tr()),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SellerShopScreen(sellerId: seller['id']),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
