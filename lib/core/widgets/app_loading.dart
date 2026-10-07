import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Loading state variants.
enum AppLoadingType {
  spinner,
  skeleton,
  overlay,
}

/// Unified loading indicator component.
class AppLoading extends StatelessWidget {
  final AppLoadingType type;
  final String? message;
  final double? size;
  final int skeletonLines;

  const AppLoading({
    super.key,
    this.type = AppLoadingType.spinner,
    this.message,
    this.size,
    this.skeletonLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case AppLoadingType.spinner:
        return _SpinnerLoading(message: message, size: size);
      case AppLoadingType.skeleton:
        return _SkeletonLoading(lines: skeletonLines);
      case AppLoadingType.overlay:
        return _OverlayLoading(message: message);
    }
  }
}

class _SpinnerLoading extends StatelessWidget {
  final String? message;
  final double? size;

  const _SpinnerLoading({this.message, this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size ?? 32,
            height: size ?? 32,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: AppTypography.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SkeletonLoading extends StatelessWidget {
  final int lines;

  const _SkeletonLoading({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (i) {
          final width = i == lines - 1 ? 0.5 : (0.7 + (i % 3) * 0.1);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _SkeletonBox(
              height: i == 0 ? 20 : 14,
              widthFraction: width,
            ),
          );
        }),
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  final double height;
  final double widthFraction;

  const _SkeletonBox({
    required this.height,
    required this.widthFraction,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.3 + (_controller.value * 0.4);
        return FractionallySizedBox(
          widthFactor: widget.widthFraction,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: AppColors.skeleton.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
        );
      },
    );
  }
}

class _OverlayLoading extends StatelessWidget {
  final String? message;

  const _OverlayLoading({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.overlay,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(message!, style: AppTypography.body),
              ],
            ],
          ),
        ),
      ),
    );
  }
}