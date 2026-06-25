import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart' hide Trans;
import '../../controllers/config_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/cart_controller.dart';
import '../main/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    final startTime = DateTime.now();

    try {
      final configController = Get.find<ConfigController>();
      final homeController = Get.find<HomeController>();
      final cartController = Get.find<CartController>();

      // Prefetch all required APIs in parallel
      await Future.wait([
        configController.fetchConfigs(),
        homeController.loadHomeData(lang: context.locale.languageCode),
        cartController.loadCart(),
      ]);
    } catch (e) {
      debugPrint('[splash] Pre-fetching failed: $e');
    }

    // Ensure the splash screen remains visible for at least 3 seconds
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(seconds: 3) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFFF8A3D), Color(0xFFFFA726)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // App Logo / Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🛍️',
                    style: TextStyle(fontSize: 56),
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 800.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              // App Name
              Text(
                'Koon',
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text(
                'كون',
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 16),
              Text(
                'splash_subtitle'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              )
                  .animate(delay: 700.ms)
                  .fadeIn(duration: 600.ms),
              const Spacer(flex: 3),
              // Loading indicator
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                ),
              )
                  .animate(delay: 1000.ms)
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
