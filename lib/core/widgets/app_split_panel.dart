import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Resizable horizontal split panel for desktop side-by-side workflows.
///
/// Usage:
/// ```dart
/// AppSplitPanel(
///   left: MedicineListView(),
///   right: MedicineDetailView(),
///   initialRatio: 0.4,
///   minLeftWidth: 300,
///   minRightWidth: 400,
/// )
/// ```
class AppSplitPanel extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double initialRatio;
  final double minLeftWidth;
  final double minRightWidth;
  final double dividerWidth;
  final bool isResizable;

  const AppSplitPanel({
    super.key,
    required this.left,
    required this.right,
    this.initialRatio = 0.4,
    this.minLeftWidth = 250,
    this.minRightWidth = 300,
    this.dividerWidth = 6,
    this.isResizable = true,
  });

  @override
  State<AppSplitPanel> createState() => _AppSplitPanelState();
}

class _AppSplitPanelState extends State<AppSplitPanel> {
  late double _ratio;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth - widget.dividerWidth;
        final minWidthRatio = widget.minLeftWidth / totalWidth;
        final maxWidthRatio = 1.0 - (widget.minRightWidth / totalWidth);

        // Clamp ratio to valid range
        _ratio = _ratio.clamp(minWidthRatio, maxWidthRatio);

        return Row(
          children: [
            // Left Panel
            SizedBox(
              width: totalWidth * _ratio,
              child: widget.left,
            ),

            // Draggable Divider
            if (widget.isResizable)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    setState(() => _isDragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final delta = details.delta.dx / totalWidth;
                      _ratio = (_ratio + delta).clamp(minWidthRatio, maxWidthRatio);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() => _isDragging = false);
                  },
                  child: Container(
                    width: widget.dividerWidth,
                    color: Colors.transparent,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isDragging ? 3 : 1,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: _isDragging
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 1,
                color: AppColors.border,
              ),

            // Right Panel
            Expanded(
              child: widget.right,
            ),
          ],
        );
      },
    );
  }
}