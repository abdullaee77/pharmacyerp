import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../domain/license.dart';
import '../controllers/license_controller.dart';

class LicenseScreen extends StatefulWidget {
  final LicenseController controller;

  /// Callback triggered when a license payload is successfully verified & activated.
  final VoidCallback? onLicenseActivated;

  const LicenseScreen({
    super.key,
    required this.controller,
    this.onLicenseActivated,
  });

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _jsonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadLicense();
    });
  }

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_jsonCtrl.text.trim().isEmpty) {
      AppToast.warning(context, 'Paste a license JSON payload to activate.');
      return;
    }
    final error = await widget.controller.activateLicense(_jsonCtrl.text);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
    } else {
      AppToast.success(context, 'License cryptographically verified and activated!');
      _jsonCtrl.clear();
      widget.onLicenseActivated?.call();
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
      case LicenseStatus.activationRequired:
      case LicenseStatus.invalid:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading && widget.controller.license == null) {
          return const AppLoading(message: 'Verifying cryptographic license...');
        }

        final lic = widget.controller.license;
        final color = _statusColor(lic?.status ?? LicenseStatus.activationRequired);
        final machineId = widget.controller.machineId;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Text('License Management', style: AppTypography.pageTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Machine Hardware Fingerprint Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phonelink_setup_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hardware Machine ID', style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          SelectableText(
                            machineId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: machineId));
                        AppToast.success(context, 'Machine ID copied to clipboard!');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Machine ID'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Status banner
              if (lic != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(lic.isValid ? Icons.verified_rounded : Icons.error_outline_rounded, size: 48, color: color),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lic.status.label, style: AppTypography.display.copyWith(fontSize: 24, color: color)),
                            Text(
                              lic.isValid
                                  ? 'License verified via offline Ed25519 digital signature. Terminal is fully operational.'
                                  : 'Action required. Paste a signed license JSON payload to activate.',
                              style: AppTypography.body,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),

              // License details
              if (lic != null && lic.payload != null) ...[
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
                      _detailRow('Product ID', lic.productId),
                      _detailRow('Edition', lic.edition),
                      _detailRow('License ID', lic.licenseKey),
                      _detailRow('Customer Name', lic.customerName),
                      _detailRow('Business Name', lic.businessName),
                      _detailRow('Machine ID Bound', lic.machineId),
                      _detailRow('Activation Date', lic.activationDate != null ? _fmt(lic.activationDate!) : '—'),
                      _detailRow('Expiry Date', lic.expiryDate != null ? _fmt(lic.expiryDate!) : 'Lifetime License'),
                      _detailRow('Days Remaining', lic.licenseType == 'lifetime' ? 'Unlimited' : '${lic.daysRemaining} days'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

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
                    Text('Activate License Payload', style: AppTypography.sectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Paste the JSON payload generated by the admin key issuer.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _jsonCtrl,
                      maxLines: 6,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '{\n  "licenseVersion": 1,\n  "licenseId": "...",\n  "signature": "..."\n}',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppButton(
                          label: 'Verify & Activate License',
                          icon: Icons.shield_rounded,
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
            child: Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}