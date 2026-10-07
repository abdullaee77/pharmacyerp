import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/components.dart';
import '../../../medicines/domain/value_objects.dart';
import '../../domain/report_models.dart';
import '../controllers/report_controller.dart';

class ReportsScreen extends StatefulWidget {
  final ReportController controller;

  const ReportsScreen({super.key, required this.controller});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.generateReport();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: widget.controller.filter.fromDate ??
            DateTime(now.year, now.month, 1),
        end: widget.controller.filter.toDate ?? now,
      ),
    );
    if (picked != null) {
      widget.controller.updateFilter(
        widget.controller.filter.copyWith(
          fromDate: picked.start,
          toDate: DateTime(
              picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        ),
      );
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final report = ctrl.currentReport;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports', style: AppTypography.pageTitle),
                    Text(
                      'Generate and review business reports.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Report type selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ReportType.values.map((type) {
                  final selected = ctrl.selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(type.label),
                      selected: selected,
                      onSelected: (_) => ctrl.selectReportType(type),
                      selectedColor: AppColors.primarySurface,
                      labelStyle: TextStyle(
                        fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Date filter
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(
                    '${_fmtDate(ctrl.filter.fromDate)} — ${_fmtDate(ctrl.filter.toDate)}',
                  ),
                ),
                const Spacer(),
                if (report != null)
                  Text(
                    '${report.totalRowCount} rows',
                    style: AppTypography.caption,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Summary totals
            if (report != null && report.summaryTotals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: report.summaryTotals.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${e.key}: ',
                              style: AppTypography.caption
                                  .copyWith(fontWeight: FontWeight.w700)),
                          Text(e.value.display,
                              style: AppTypography.numeric.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              )),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Report table
            Expanded(child: _buildReportTable(ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildReportTable(ReportController ctrl) {
    if (ctrl.isLoading) {
      return const AppLoading(message: 'Generating report...');
    }
    if (ctrl.error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: ctrl.error!,
        actionLabel: 'Retry',
        onAction: ctrl.generateReport,
      );
    }

    final report = ctrl.currentReport;
    if (report == null || report.rows.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No data for this report',
        subtitle: 'Try adjusting the date range or filters.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowHeight: 42,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 48,
            horizontalMargin: AppSpacing.md,
            columnSpacing: AppSpacing.lg,
            headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceVariant),
            columns: report.headers
                .map((h) => DataColumn(
              label: Text(h, style: AppTypography.tableHeader),
            ))
                .toList(),
            rows: report.rows.map((row) {
              final values = [
                row.string0,
                row.string1,
                row.string2,
                row.string3,
                row.string4,
                row.string5,
              ];
              return DataRow(
                cells: List.generate(
                  report.headers.length,
                      (i) {
                    final val = i < values.length ? values[i] : '';
                    final isNumeric = _isNumericColumn(report.type, i);
                    return DataCell(
                      isNumeric
                          ? Text(
                        _formatNumeric(val),
                        style: AppTypography.numericSmall,
                        textAlign: TextAlign.right,
                      )
                          : Text(
                        _truncate(val, 30),
                        style: AppTypography.tableCell,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  bool _isNumericColumn(ReportType type, int colIndex) {
    switch (type) {
      case ReportType.sales:
        return colIndex == 3 || colIndex == 4;
      case ReportType.purchases:
        return colIndex == 3;
      case ReportType.profit:
        return colIndex >= 1;
      case ReportType.inventory:
        return colIndex >= 2;
      case ReportType.expiry:
        return colIndex == 3 || colIndex == 4;
      case ReportType.customers:
        return colIndex == 2;
      case ReportType.suppliers:
        return colIndex == 2;
      case ReportType.accounts:
        return colIndex >= 2;
    }
  }

  String _formatNumeric(String val) {
    final n = int.tryParse(val);
    if (n == null) return val;
    if (n.abs() > 100) {
      return Money.fromPaisa(n).display;
    }
    return n.toString();
  }

  String _truncate(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}