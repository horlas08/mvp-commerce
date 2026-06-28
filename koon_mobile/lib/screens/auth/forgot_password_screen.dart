import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authController = Get.find<AuthController>();
  bool _sent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  // Inline error shown when the email is not registered
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    setState(() => _emailError = null);
    if (!_formKey.currentState!.validate()) return;
    try {
      final success = await _authController.forgotPassword(_emailController.text.trim());
      if (success && mounted) {
        // Show custom branded snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'reset_password_code_sent'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _sent = true);
      }
    } on UserNotFoundException {
      // Show inline error on the email field
      setState(() => _emailError = 'no_account_found_for_email'.tr());
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await _authController.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _passwordController.text,
    );
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
          child: Form(
            key: _formKey,
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
                const SizedBox(height: 40),
                Icon(
                  _sent ? Icons.mark_email_read_outlined : Icons.lock_reset_outlined,
                  size: 64,
                  color: AppColors.primary,
                ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),
                Text(
                  _sent ? 'enter_6digit_code'.tr() : 'reset_password'.tr(),
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 12),
                Text(
                  _sent ? 'reset_password_code_sent'.tr() : 'enter_email_reset_code'.tr(),
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 40),
                if (!_sent) ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'email'.tr(),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                      errorText: _emailError,
                    ),
                    onChanged: (_) {
                      if (_emailError != null) setState(() => _emailError = null);
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'email_is_required'.tr();
                      if (!v.contains('@')) return 'enter_valid_email'.tr();
                      return null;
                    },
                  ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 28),
                  Obx(() => SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _authController.isLoading.value ? null : _handleReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _authController.isLoading.value
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('send_code'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      )).animate(delay: 500.ms).fadeIn(duration: 400.ms),
                ] else ...[
                  TextFormField(
                    controller: _emailController,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'email'.tr(),
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'enter_verification_code'.tr(),
                      prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.textHint),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'enter_verification_code'.tr();
                      if (v.length < 6) return 'enter_verification_code'.tr();
                      return null;
                    },
                  ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'new_password'.tr(),
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
                      if (v == null || v.isEmpty) return 'new_password_required'.tr();
                      if (v.length < 6) return 'password_min_length'.tr();
                      return null;
                    },
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'confirm_new_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'confirm_new_password'.tr();
                      if (v != _passwordController.text) return 'passwords_dont_match'.tr();
                      return null;
                    },
                  ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 28),
                  Obx(() => SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _authController.isLoading.value ? null : _handleResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _authController.isLoading.value
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('reset_password_button'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      )).animate(delay: 400.ms).fadeIn(duration: 400.ms),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('back_to_login'.tr(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
