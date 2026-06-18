import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Orange
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8A3D);
  static const Color primaryDark = Color(0xFFE65C00);
  static const Color primarySurface = Color(0xFFFFF3E8);

  // Secondary - Blue
  static const Color secondary = Color(0xFF1565C0);
  static const Color secondaryLight = Color(0xFF42A5F5);
  static const Color secondaryDark = Color(0xFF0D47A1);
  static const Color secondarySurface = Color(0xFFE3F2FD);

  // Neutrals
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient profileHeaderGradient = LinearGradient(
    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
