import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/navigation_item.dart';

/// Desktop Footer Status Bar: Dynamic context-aware operational telemetry.
class StatusBar extends StatelessWidget {
  final NavigationItem? activeModule;
  final bool isFullscreen;
  final String? activeContext;

  const StatusBar({
    super.key,
    this.activeModule,
    this.isFullscreen = false,
    this.activeContext,
  });

  @override
  Widget build(BuildContext context) {
    if (isFullscreen) return const SizedBox.shrink();

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Database Engine Indicator ──────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.storage_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'SQLite (Local)',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(width: AppSpacing.lg),
          _Divider(),
          const SizedBox(width: AppSpacing.lg),

          // ── Active Module Context ──────────────────────────────
          if (activeModule != null) ...[
            Icon(
              activeModule!.icon,
              size: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              activeModule!.label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            _Divider(),
            const SizedBox(width: AppSpacing.lg),
          ],

          // ── Terminal Station ───────────────────────────────────
          Text(
            'Terminal: POS-01 (Offline)',
            style: AppTypography.caption,
          ),

          const Spacer(),

          // ── Dynamic Shortcut Hints ─────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShortcutHint(keyLabel: 'Ctrl+K', desc: 'Search'),
              const SizedBox(width: AppSpacing.md),
              _ShortcutHint(keyLabel: 'Ctrl+F1', desc: 'Ribbon'),
              const SizedBox(width: AppSpacing.md),
              _ShortcutHint(keyLabel: 'Ctrl+Shift+F', desc: 'Fullscreen'),
              const SizedBox(width: AppSpacing.md),
              _ShortcutHint(keyLabel: 'Alt+1-0', desc: 'Navigate'),
            ],
          ),

          const SizedBox(width: AppSpacing.lg),
          _Divider(),
          const SizedBox(width: AppSpacing.lg),

          // ── Build Version ──────────────────────────────────────
          Text(
            'v1.0.0-phase1',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 14, color: AppColors.border);
  }
}

class _ShortcutHint extends StatelessWidget {
  final String keyLabel;
  final String desc;

  const _ShortcutHint({
    required this.keyLabel,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          keyLabel,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          desc,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}