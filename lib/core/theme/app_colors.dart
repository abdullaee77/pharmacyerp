import 'package:flutter/material.dart';

/// Design token palette for the Pharmacy ERP.
///
/// Restrained teal/emerald primary with neutral slate tones.
/// All colors are constant and can be used in const contexts.
class AppColors {
  AppColors._();

  // ── Primary (Teal) ──────────────────────────────────────────
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF0D5F58);
  static const Color primarySurface = Color(0xFFF0FDFA);

  // ── Secondary (Blue) ────────────────────────────────────────
  static const Color secondary = Color(0xFF1E40AF);
  static const Color secondaryLight = Color(0xFF3B82F6);
  static const Color secondarySurface = Color(0xFFEFF6FF);

  // ── Accent (Emerald) ────────────────────────────────────────
  static const Color accent = Color(0xFF059669);
  static const Color accentLight = Color(0xFF34D399);

  // ── Background & Surface ────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color surfaceHover = Color(0xFFF8FAFC);

  // ── Border ──────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFFCBD5E1);
  static const Color borderFocus = Color(0xFF0F766E);

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFF0F766E);

  // ── Semantic ────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFFF0FDF4);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFFFBEB);

  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFFFEF2F2);

  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFF3B82F6);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ── Misc ────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE2E8F0);
  static const Color overlay = Color(0x1A0F172A);
  static const Color disabled = Color(0xFFE2E8F0);
  static const Color disabledText = Color(0xFF94A3B8);
  static const Color skeleton = Color(0xFFE2E8F0);
}