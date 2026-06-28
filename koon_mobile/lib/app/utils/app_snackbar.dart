import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import '../theme/app_colors.dart';

/// Centralised snackbar helper used throughout the app.
///
/// Variants:
///   • [success] — green  ✔  (e.g. "Added to cart")
///   • [error]   — red    ✗  (e.g. "Error occurred")
///   • [info]    — primary blue ℹ (e.g. "Please sign in")
///   • [warning] — amber  ⚠  (e.g. "Already in compare list")
///
/// Usage from a widget (with BuildContext):
///   AppSnackbar.success(context, 'added_to_cart'.tr());
///
/// Usage from a controller / anywhere (uses Get.context):
///   AppSnackbar.success(null, 'added_to_cart'.tr());
abstract class AppSnackbar {
  // ─── duration presets ────────────────────────────────────────────────
  static const Duration _short = Duration(seconds: 2);
  static const Duration _medium = Duration(seconds: 3);

  // ─── public entry points ─────────────────────────────────────────────

  static void success(BuildContext? ctx, String message,
      {Duration duration = _short}) {
    _show(
      ctx,
      message: message,
      icon: Icons.check_circle_rounded,
      backgroundColor: AppColors.success,
      duration: duration,
    );
  }

  static void error(BuildContext? ctx, String message,
      {Duration duration = _medium}) {
    _show(
      ctx,
      message: message,
      icon: Icons.error_rounded,
      backgroundColor: AppColors.error,
      duration: duration,
    );
  }

  static void info(BuildContext? ctx, String message,
      {IconData icon = Icons.info_outline_rounded,
      Duration duration = _medium}) {
    _show(
      ctx,
      message: message,
      icon: icon,
      backgroundColor: AppColors.primary,
      duration: duration,
    );
  }

  static void warning(BuildContext? ctx, String message,
      {Duration duration = _medium}) {
    _show(
      ctx,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: AppColors.warning,
      duration: duration,
    );
  }

  // ─── core builder ────────────────────────────────────────────────────

  static void _show(
    BuildContext? ctx, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      duration: duration,
      elevation: 4,
    );

    final effectiveCtx = ctx ?? Get.context;
    if (effectiveCtx != null) {
      ScaffoldMessenger.of(effectiveCtx)
        ..hideCurrentSnackBar()
        ..showSnackBar(snackBar);
    }
  }
}
