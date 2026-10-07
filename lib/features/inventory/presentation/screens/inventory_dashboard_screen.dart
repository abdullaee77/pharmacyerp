import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/batch.dart';
import '../../domain/inventory_movement.dart';
import '../controllers/inventory_controller.dart';
import '../controllers/batch_controller.dart';

/// Inventory Dashboard — answers "What is happening with my pharmacy stock?"
class InventoryDashboardScreen extends StatefulWidget {
  final InventoryController inventoryController;
  final BatchController batchController;

  const InventoryDashboardScreen({
    super.key,
    required this.inventoryController,
    required this.batchController,
  });

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.inventoryController.loadStockLevels();
      widget.batchController.loadBatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.inventoryController,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: widget.batchController,
          builder: (context, _) {
            return _buildContent();
          },
        );
      },
    );
  }

  Widget _buildContent() {
    final stocks = widget.inventoryController.stocks;
    final batches = widget.batchController.batches;

    final totalMedicines = stocks.length;
    final totalStockUnits =
    stocks.fold<int>(0, (sum, s) => sum + s.currentStock.value);
    final totalStockValue = stocks.fold<int>(
      0,
          (sum, s) =>
      sum + (s.medicine.sellingPrice.paisa * s.currentStock.value),
    );
    final outOfStockCount = stocks.where((s) => s.isOutOfStock).length;
    final lowStockCount = stocks.where((s) => s.isLowStock).length;
    final expiredCount =
        batches.where((b) => b.status == BatchStatus.expired).length;
    final expiringSoonCount =
        batches.where((b) => b.status == BatchStatus.expiringSoon).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory Dashboard',
                    style: AppTypography.pageTitle,
                  ),
                  Text(
                    'Real-time pharmacy stock overview and expiry monitoring.',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  widget.inventoryController.loadStockLevels();
                  widget.batchController.loadBatches();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // KPI Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 900 ? 3 : 6;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.6,
                children: [
                  _MetricCard(
                    title: 'TOTAL MEDICINES',
                    value: '$totalMedicines',
                    icon: Icons.medication_rounded,
                    color: AppColors.primary,
                  ),
                  _MetricCard(
                    title: 'TOTAL UNITS',
                    value: '$totalStockUnits',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.secondary,
                  ),
                  _MetricCard(
                    title: 'STOCK VALUE',
                    value: Money.fromPaisa(totalStockValue).display,
                    icon: Icons.attach_money_rounded,
                    color: AppColors.accent,
                  ),
                  _MetricCard(
                    title: 'OUT OF STOCK',
                    value: '$outOfStockCount',
                    icon: Icons.remove_circle_outline_rounded,
                    color: AppColors.error,
                  ),
                  _MetricCard(
                    title: 'LOW STOCK',
                    value: '$lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  _MetricCard(
                    title: 'EXPIRED',
                    value: '$expiredCount',
                    icon: Icons.event_busy_rounded,
                    color: AppColors.error,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Two-column detail panels
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Expiry Overview
              Expanded(
                flex: 1,
                child: _ExpiryOverviewPanel(
                  batches: batches,
                  expiredCount: expiredCount,
                  expiringSoonCount: expiringSoonCount,
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              // Right: Low Stock Alert List
              Expanded(
                flex: 1,
                child: _LowStockPanel(
                  stocks: stocks
                      .where((s) => s.isLowStock || s.isOutOfStock)
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.huge),
        ],
      ),
    );
  }
}

// ─── Metric Card ────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppElevation.shadowSm,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            value,
            style: AppTypography.numericLarge.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Expiry Overview Panel ──────────────────────────────────────────

class _ExpiryOverviewPanel extends StatelessWidget {
  final List<Batch> batches;
  final int expiredCount;
  final int expiringSoonCount;

  const _ExpiryOverviewPanel({
    required this.batches,
    required this.expiredCount,
    required this.expiringSoonCount,
  });

  @override
  Widget build(BuildContext context) {
    final normalCount =
        batches.where((b) => b.status == BatchStatus.normal).length;
    final total = batches.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Expiry Overview', style: AppTypography.sectionTitle),
        const SizedBox(height: AppSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            children: [
              // Visual bar
              if (total > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        _BarSegment(
                          flex: expiredCount,
                          color: AppColors.error,
                          total: total,
                        ),
                        _BarSegment(
                          flex: expiringSoonCount,
                          color: AppColors.warning,
                          total: total,
                        ),
                        _BarSegment(
                          flex: normalCount,
                          color: AppColors.success,
                          total: total,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendItem(
                    color: AppColors.error,
                    label: 'Expired',
                    count: expiredCount,
                  ),
                  _LegendItem(
                    color: AppColors.warning,
                    label: 'Expiring Soon',
                    count: expiringSoonCount,
                  ),
                  _LegendItem(
                    color: AppColors.success,
                    label: 'Normal',
                    count: normalCount,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '$total total active batches tracked',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarSegment extends StatelessWidget {
  final int flex;
  final Color color;
  final int total;

  const _BarSegment({
    required this.flex,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (flex == 0 || total == 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: Container(color: color),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: AppTypography.numeric.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ─── Low Stock Panel ────────────────────────────────────────────────

class _LowStockPanel extends StatelessWidget {
  final List<InventoryStock> stocks;

  const _LowStockPanel({required this.stocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Low Stock & Out of Stock Alerts',
          style: AppTypography.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.md),
        if (stocks.isEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'All stock levels are healthy',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'No products are below minimum reorder thresholds.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stocks.length > 10 ? 10 : stocks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final s = stocks[i];
                  final isOut = s.isOutOfStock;

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: (isOut
                          ? AppColors.error
                          : AppColors.warning)
                          .withValues(alpha: 0.1),
                      child: Icon(
                        isOut
                            ? Icons.remove_circle_outline
                            : Icons.warning_amber_rounded,
                        size: 15,
                        color:
                        isOut ? AppColors.error : AppColors.warning,
                      ),
                    ),
                    title: Text(
                      s.medicine.name,
                      style: AppTypography.subtitle.copyWith(fontSize: 13),
                    ),
                    subtitle: Text(
                      'Current: ${s.currentStock.value} / Min: ${s.medicine.minStockLevel.value}',
                      style: AppTypography.caption,
                    ),
                    trailing: AppBadge(
                      label: isOut ? 'EMPTY' : 'LOW',
                      variant: isOut
                          ? AppBadgeVariant.error
                          : AppBadgeVariant.warning,
                    ),
                  );
                },
              ),
            ),
          ),
        if (stocks.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '...and ${stocks.length - 10} more items',
              style: AppTypography.caption,
            ),
          ),
      ],
    );
  }
}