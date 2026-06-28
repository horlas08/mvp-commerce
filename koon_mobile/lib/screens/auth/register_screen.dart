import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialEmail;
  const RegisterScreen({super.key, this.initialEmail});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authController = Get.find<AuthController>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await _authController.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
    if (success && mounted) {
      // Show custom branded snackbar for verification code
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
      // Go to email verification — only pop true once the user verifies
      final verified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
      );
      if (verified == true && mounted) {
        // Pop back to wherever register was opened from (e.g. webview add-to-cart)
        Navigator.pop(context, true);
      }
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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'register'.tr(),
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'create_account_desc'.tr(),
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary),
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'name'.tr(),
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.textHint),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'name_is_required'.tr() : null,
                    ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
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
                    ).animate(delay: 250.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'phone'.tr(),
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textHint),
                      ),
                    ).animate(delay: 300.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'password'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textHint),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'password_is_required'.tr();
                        if (v.length < 6) return 'password_min_length'.tr();
                        return null;
                      },
                    ).animate(delay: 350.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'confirm_password'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
                      ),
                      validator: (v) {
                        if (v != _passwordController.text) return 'passwords_dont_match'.tr();
                        return null;
                      },
                    ).animate(delay: 400.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Obx(() => SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _authController.isLoading.value ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _authController.isLoading.value
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('sign_up'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  )).animate(delay: 450.ms).fadeIn(duration: 300.ms),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('already_have_account'.tr(), style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: Text('sign_in'.tr(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ).animate(delay: 500.ms).fadeIn(duration: 300.ms),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
