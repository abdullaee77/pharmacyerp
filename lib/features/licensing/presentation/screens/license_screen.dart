import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/license.dart';
import '../controllers/license_controller.dart';

class LicenseScreen extends StatefulWidget {
  final LicenseController controller;

  const LicenseScreen({super.key, required this.controller});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadLicense();
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_keyCtrl.text.trim().isEmpty) {
      AppToast.warning(context, 'Enter a license key.');
      return;
    }
    final error = await widget.controller.activateLicense(_keyCtrl.text);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'License activated successfully!');
      _keyCtrl.clear();
    }
  }

  Color _statusColor(LicenseStatus s) {
    switch (s) {
      case LicenseStatus.active:
        return AppColors.success;
      case LicenseStatus.trial:
        return AppColors.info;
      case LicenseStatus.expiringSoon:
        return AppColors.warning;
      case LicenseStatus.offlineGrace:
        return AppColors.warning;
      case LicenseStatus.expired:
        return AppColors.error;
      case LicenseStatus.activationRequired:
        return AppColors.error;
      case LicenseStatus.invalid:
        return AppColors.error;
    }
  }

  AppBadgeVariant _statusBadge(LicenseStatus s) {
    switch (s) {
      case LicenseStatus.active:
        return AppBadgeVariant.success;
      case LicenseStatus.trial:
        return AppBadgeVariant.info;
      case LicenseStatus.expiringSoon:
        return AppBadgeVariant.warning;
      case LicenseStatus.offlineGrace:
        return AppBadgeVariant.warning;
      default:
        return AppBadgeVariant.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading && widget.controller.license == null) {
          return const AppLoading(message: 'Checking license...');
        }

        final lic = widget.controller.license;
        if (lic == null) {
          return AppEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Unable to load license',
            subtitle: widget.controller.error ?? 'Unknown error.',
            actionLabel: 'Retry',
            onAction: widget.controller.loadLicense,
          );
        }

        final color = _statusColor(lic.status);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('License Management', style: AppTypography.pageTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Status banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      lic.isValid
                          ? Icons.verified_rounded
                          : Icons.error_outline_rounded,
                      size: 48,
                      color: color,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lic.status.label,
                            style: AppTypography.display.copyWith(
                              fontSize: 24,
                              color: color,
                            ),
                          ),
                          Text(
                            lic.isValid
                                ? 'Your license is valid. All features are operational.'
                                : 'Action required. Please activate or renew your license.',
                            style: AppTypography.body,
                          ),
                        ],
                      ),
                    ),
                    AppBadge(
                      label: lic.status.label,
                      variant: _statusBadge(lic.status),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // License details
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('License Details', style: AppTypography.sectionTitle),
                    const SizedBox(height: AppSpacing.lg),
                    _detailRow('Product', lic.productId),
                    _detailRow('Edition', lic.edition),
                    _detailRow('License Key', lic.licenseKey),
                    _detailRow('Licensed To', lic.licensedTo),
                    _detailRow(
                      'Activation Date',
                      lic.activationDate != null
                          ? _fmt(lic.activationDate!)
                          : '—',
                    ),
                    _detailRow(
                      'Expiry Date',
                      lic.expiryDate != null ? _fmt(lic.expiryDate!) : '—',
                    ),
                    _detailRow('Days Remaining', '${lic.daysRemaining}'),
                    _detailRow('Max Users', '${lic.maxUsers}'),
                    _detailRow('Max Counters', '${lic.maxCounters}'),
                    const SizedBox(height: AppSpacing.md),
                    Text('Enabled Modules', style: AppTypography.subtitle),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: lic.enabledModules
                          .map(
                            (m) => AppBadge(
                              label: m,
                              variant: AppBadgeVariant.primary,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Activation form
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activate / Renew License',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Enter your license key to activate or renew.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _keyCtrl,
                            label: 'License Key',
                            hint: 'XXXX-XXXX-XXXX-XXXX',
                            prefixIcon: Icons.key_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppButton(
                          label: 'Activate',
                          icon: Icons.verified_rounded,
                          variant: AppButtonVariant.primary,
                          isLoading: widget.controller.isLoading,
                          onPressed: _activate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
