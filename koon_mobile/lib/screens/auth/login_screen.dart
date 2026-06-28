import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = Get.find<AuthController>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final result = await _authController.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (result == LoginResult.success) {
        Navigator.pop(context, true);
      } else if (result == LoginResult.needsVerification) {
        // Email registered but not yet verified — show branded snackbar then go to verify
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'verification_code_sent'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        final verified = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
        );
        if (verified == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } on UserNotFoundException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'no_account_redirect_register'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final result = await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(initialEmail: e.email),
        ),
      );
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await _authController.signInWithGoogle();
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Back button
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Text(
                'welcome_back'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'login_to_continue'.tr(),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 40),
              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'email'.tr(),
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'email_is_required'.tr();
                        if (!v.contains('@')) return 'enter_valid_email'.tr();
                        return null;
                      },
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'password'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textHint,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'password_is_required'.tr();
                        if (v.length < 6) return 'password_min_length'.tr();
                        return null;
                      },
                    ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Forgot password
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                    if (result == true && mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(
                    'forgot_password'.tr(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Login button
              Obx(() => SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _authController.isLoading.value ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _authController.isLoading.value
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text('sign_in'.tr(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  )).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),
              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or_continue_with'.tr(),
                        style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ).animate(delay: 500.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              // Google Sign In
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _handleGoogleSignIn,
                  icon: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  label: Text('google'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 32),
              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('dont_have_account'.tr(),
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text('sign_up'.tr(),
                        style: const TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
