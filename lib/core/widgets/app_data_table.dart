import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import 'app_empty_state.dart';
import 'app_loading.dart';

/// Column definition for [AppDataTable].
class AppDataColumn {
  final String label;
  final double? width;
  final bool isNumeric;
  final bool isSortable;

  const AppDataColumn({
    required this.label,
    this.width,
    this.isNumeric = false,
    this.isSortable = false,
  });
}

/// Desktop data table wrapper with built-in loading, empty, and error states.
class AppDataTable extends StatelessWidget {
  final List<AppDataColumn> columns;
  final List<List<Widget>> rows;
  final bool isLoading;
  final String? error;
  final String emptyTitle;
  final String? emptySubtitle;
  final VoidCallback? onRetry;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.error,
    this.emptyTitle = 'No records found',
    this.emptySubtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: AppLoading(type: AppLoadingType.spinner, message: 'Loading data...'),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: error!,
          actionLabel: onRetry != null ? 'Retry' : null,
          onAction: onRetry,
        ),
      );
    }

    if (rows.isEmpty) {
      return AppEmptyState(
        icon: Icons.table_rows_rounded,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns
            .map((c) => DataColumn(
                  label: Text(c.label),
                  numeric: c.isNumeric,
                ))
            .toList(),
        rows: rows
            .map((cells) => DataRow(
                  cells: cells.map((cell) => DataCell(cell)).toList(),
                ))
            .toList(),
      ),
    );
  }
}