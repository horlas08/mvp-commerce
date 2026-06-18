import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authController = Get.find<AuthController>();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    await _authController.forgotPassword(_emailController.text.trim());
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
              const SizedBox(height: 40),
              Icon(
                _sent ? Icons.mark_email_read_outlined : Icons.lock_reset_outlined,
                size: 64,
                color: AppColors.primary,
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'reset_password'.tr(),
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 12),
              Text(
                'enter_email_reset'.tr(),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 40),
              if (!_sent) ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
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
                  ),
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
                            : Text('send_reset_link'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    )).animate(delay: 500.ms).fadeIn(duration: 400.ms),
              ] else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                      const SizedBox(height: 12),
                      Text('check_email_reset_link'.tr(),
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('back_to_login'.tr(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
