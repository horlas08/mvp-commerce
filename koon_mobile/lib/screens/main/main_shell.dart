import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/compare_controller.dart';
import '../home/home_screen.dart';
import '../categories/categories_screen.dart';
import '../cart/cart_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/email_verification_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(),
    const CartScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Obx(() {
      if (authController.isLoggedIn.value &&
          authController.user.value != null &&
          authController.user.value!['is_verified'] == false) {
        return const EmailVerificationScreen();
      }

      return Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'home'.tr()),
                  _buildNavItem(1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'categories'.tr()),
                  _buildCartNavItem(),
                  _buildNavItem(3, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'orders'.tr()),
                  _buildNavItem(4, Icons.person_outline, Icons.person_rounded, 'profile'.tr()),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.grey[400]! : AppColors.textHint;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : unselectedColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartNavItem() {
    final isActive = _currentIndex == 2;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.grey[400]! : AppColors.textHint;

    return InkWell(
      onTap: () => setState(() => _currentIndex = 2),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GetX<CartController>(builder: (controller) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                    color: isActive ? AppColors.primary : unselectedColor,
                    size: 24,
                  ),
                  if (controller.totalCartCount.value > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${controller.totalCartCount.value}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().scale(duration: 200.ms, curve: Curves.elasticOut),
                    ),
                ],
              );
            }),
            const SizedBox(height: 4),
            Text(
              'cart'.tr(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
