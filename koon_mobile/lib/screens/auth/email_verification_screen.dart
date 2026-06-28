import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart' hide Trans;
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme/app_colors.dart';
import '../../controllers/auth_controller.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _authController = Get.find<AuthController>();
  
  int _resendCooldown = 30;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _resendCooldown = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 1) {
        setState(() {
          _canResend = true;
        });
        _timer?.cancel();
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await _authController.verifyEmail(_codeController.text.trim());
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'email_verified_success'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;
    await _authController.resendVerification();
    _startTimer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 18),
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _authController.userEmail;
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    // Animated Email Icon
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 44,
                          color: AppColors.primary,
                        ),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut)
                          .fadeIn(duration: 400.ms),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title
                    Text(
                      'email_verification'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 12),
                    
                    // Subtitle
                    Text(
                      'verification_sent_to'.tr(args: [email]),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 40),
                    
                    // Code Input Form
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: GoogleFonts.poppins(
                            color: AppColors.textHint.withOpacity(0.5),
                            letterSpacing: 8,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'enter_verification_code'.tr();
                          }
                          if (v.length != 6) {
                            return 'enter_verification_code'.tr();
                          }
                          return null;
                        },
                      ),
                    ).animate(delay: 400.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                    const SizedBox(height: 32),
                    
                    // Verify Button
                    Obx(() => SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _authController.isLoading.value ? null : _handleVerify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _authController.isLoading.value
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    'verify'.tr(),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                          ),
                        )).animate(delay: 500.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 20),
                    
                    // Resend Button
                    Center(
                      child: TextButton(
                        onPressed: _canResend ? _handleResend : null,
                        child: Text(
                          _canResend
                              ? 'resend_code'.tr()
                              : 'resend_in'.tr(args: [_resendCooldown.toString()]),
                          style: TextStyle(
                            color: _canResend ? AppColors.primary : AppColors.textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
                    
                    const Spacer(),
                    
                    // Logout / Guest Mode Option
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _authController.logout(),
                        icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                        label: Text(
                          'logout'.tr(),
                          style: GoogleFonts.inter(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
