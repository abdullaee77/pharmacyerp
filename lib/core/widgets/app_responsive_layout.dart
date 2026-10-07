import 'package:flutter/material.dart';

/// Desktop breakpoint definitions for the ERP workspace.
enum DesktopBreakpoint {
  /// Window width < 1000px — Compact single-column layout.
  compact,

  /// Window width 1000–1400px — Standard two-column layout.
  standard,

  /// Window width > 1400px — Wide multi-panel layout.
  wide,
}

/// Returns the active breakpoint for a given width.
DesktopBreakpoint resolveBreakpoint(double width) {
  if (width < 1000) return DesktopBreakpoint.compact;
  if (width <= 1400) return DesktopBreakpoint.standard;
  return DesktopBreakpoint.wide;
}

/// Responsive layout builder that provides the current [DesktopBreakpoint]
/// to its child builder.
///
/// Usage:
/// ```dart
/// AppResponsiveLayout(
///   builder: (context, breakpoint, constraints) {
///     if (breakpoint == DesktopBreakpoint.wide) {
///       return ThreePanelLayout(...);
///     }
///     return SinglePanelLayout(...);
///   },
/// )
/// ```
class AppResponsiveLayout extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    DesktopBreakpoint breakpoint,
    BoxConstraints constraints,
  ) builder;

  const AppResponsiveLayout({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = resolveBreakpoint(constraints.maxWidth);
        return builder(context, breakpoint, constraints);
      },
    );
  }
}

/// Helper to get the current breakpoint from a [BuildContext].
///
/// Uses [MediaQuery] as a fallback when [LayoutBuilder] is not available.
DesktopBreakpoint currentBreakpoint(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return resolveBreakpoint(width);
}

/// Returns the recommended grid column count for the current breakpoint.
int gridColumnsForBreakpoint(DesktopBreakpoint breakpoint, {int maxColumns = 4}) {
  switch (breakpoint) {
    case DesktopBreakpoint.compact:
      return maxColumns <= 2 ? maxColumns : 2;
    case DesktopBreakpoint.standard:
      return maxColumns <= 3 ? maxColumns : 3;
    case DesktopBreakpoint.wide:
      return maxColumns;
  }
}