import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';

/// Live component gallery for visual verification of the design system.
class ComponentShowcase extends StatelessWidget {
  const ComponentShowcase({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Component Library', style: AppTypography.pageTitle),
          const SizedBox(height: 4),
          Text(
            'Global reusable widgets and interaction states.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Buttons ──────────────────────────────────────────
          _SectionTitle('Buttons'),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              const AppButton(label: 'Primary', variant: AppButtonVariant.primary),
              const AppButton(label: 'Outlined', variant: AppButtonVariant.outlined),
              const AppButton(label: 'Ghost', variant: AppButtonVariant.ghost),
              const AppButton(label: 'Danger', variant: AppButtonVariant.danger),
              const AppButton(label: 'Success', variant: AppButtonVariant.success),
              const AppButton(label: 'Disabled', onPressed: null),
              const AppButton(label: 'Loading', isLoading: true),
              const AppButton(
                label: 'With Icon',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
              ),
              const AppButton(
                label: 'Small',
                size: AppButtonSize.small,
                variant: AppButtonVariant.primary,
              ),
              const AppButton(
                label: 'Large',
                size: AppButtonSize.large,
                variant: AppButtonVariant.primary,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Badges ───────────────────────────────────────────
          _SectionTitle('Badges'),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: const [
              AppBadge(label: 'In Stock', variant: AppBadgeVariant.success, isDot: true),
              AppBadge(label: 'Low Stock', variant: AppBadgeVariant.warning, isDot: true),
              AppBadge(label: 'Out of Stock', variant: AppBadgeVariant.error, isDot: true),
              AppBadge(label: 'Near Expiry', variant: AppBadgeVariant.warning, icon: Icons.event_busy_rounded),
              AppBadge(label: 'Expired', variant: AppBadgeVariant.error, icon: Icons.block_rounded),
              AppBadge(label: 'Active', variant: AppBadgeVariant.primary, isDot: true),
              AppBadge(label: 'Pending', variant: AppBadgeVariant.info, isDot: true),
              AppBadge(label: 'Draft', variant: AppBadgeVariant.neutral),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Text Fields ──────────────────────────────────────
          _SectionTitle('Text Fields'),
          SizedBox(
            width: 400,
            child: Column(
              children: const [
                AppTextField(
                  label: 'Medicine Name',
                  hint: 'e.g. Paracetamol 500mg',
                  prefixIcon: Icons.medication_outlined,
                  isRequired: true,
                ),
                SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Batch Number',
                  hint: 'e.g. BN-2024-0892',
                  prefixIcon: Icons.tag_rounded,
                  helperText: 'Enter the manufacturer batch number.',
                ),
                SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Error State',
                  hint: 'Invalid input',
                  errorText: 'This field contains an invalid value.',
                  prefixIcon: Icons.error_outline_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Search Bar ───────────────────────────────────────
          _SectionTitle('Search Bar'),
          AppSearchBar(
            hint: 'Search medicines, batches, customers...',
            shortcutLabel: 'Ctrl+K',
            onSearch: (_) {},
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Loading States ───────────────────────────────────
          _SectionTitle('Loading States'),
          Row(
            children: [
              Expanded(
                child: _ShowcaseCard(
                  label: 'Spinner',
                  child: const SizedBox(
                    height: 80,
                    child: AppLoading(type: AppLoadingType.spinner, message: 'Fetching...'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _ShowcaseCard(
                  label: 'Skeleton',
                  child: const AppLoading(type: AppLoadingType.skeleton, skeletonLines: 4),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Empty State ──────────────────────────────────────
          _SectionTitle('Empty State'),
          _ShowcaseCard(
            label: 'Empty List',
            child: const SizedBox(
              height: 180,
              child: AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No medicines registered',
                subtitle: 'Add your first medicine to start managing inventory.',
                actionLabel: 'Add Medicine',
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Data Table ───────────────────────────────────────
          _SectionTitle('Data Table'),
          AppDataTable(
            columns: const [
              AppDataColumn(label: 'Medicine'),
              AppDataColumn(label: 'Batch'),
              AppDataColumn(label: 'Stock', isNumeric: true),
              AppDataColumn(label: 'Status'),
            ],
            rows: [
              [
                const Text('Paracetamol 500mg'),
                const Text('BN-2024-001'),
                const Text('240'),
                const AppBadge(label: 'In Stock', variant: AppBadgeVariant.success, isDot: true),
              ],
              [
                const Text('Amoxicillin 250mg'),
                const Text('BN-2024-014'),
                const Text('0'),
                const AppBadge(label: 'Out of Stock', variant: AppBadgeVariant.error, isDot: true),
              ],
              [
                const Text('Ibuprofen 400mg'),
                const Text('BN-2023-892'),
                const Text('12'),
                const AppBadge(label: 'Near Expiry', variant: AppBadgeVariant.warning, isDot: true),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Dialog & Toast Triggers ──────────────────────────
          _SectionTitle('Dialogs & Toasts'),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              AppButton(
                label: 'Confirm Dialog',
                variant: AppButtonVariant.primary,
                onPressed: () => AppDialog.confirm(
                  context,
                  title: 'Delete Medicine?',
                  message: 'This action cannot be undone. The medicine and all associated batches will be permanently removed.',
                  confirmLabel: 'Delete',
                  confirmVariant: AppButtonVariant.danger,
                ),
              ),
              AppButton(
                label: 'Info Dialog',
                variant: AppButtonVariant.outlined,
                onPressed: () => AppDialog.info(
                  context,
                  title: 'Sync Complete',
                  message: 'All local records have been synchronized with the central database.',
                ),
              ),
              AppButton(
                label: 'Success Toast',
                variant: AppButtonVariant.success,
                onPressed: () => AppToast.success(context, 'Invoice #INV-2024-0093 saved successfully.'),
              ),
              AppButton(
                label: 'Error Toast',
                variant: AppButtonVariant.danger,
                onPressed: () => AppToast.error(context, 'Failed to connect to the database engine.'),
              ),
              AppButton(
                label: 'Warning Toast',
                variant: AppButtonVariant.outlined,
                onPressed: () => AppToast.warning(context, 'Stock for Paracetamol 500mg is below reorder level.'),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(title, style: AppTypography.sectionTitle),
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _ShowcaseCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}