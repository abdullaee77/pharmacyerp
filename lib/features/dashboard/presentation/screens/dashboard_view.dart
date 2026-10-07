import 'package:flutter/material.dart';
import '../../../../core/widgets/components.dart';

/// Legacy dashboard view — now redirects to the real Business Dashboard.
///
/// The actual implementation lives in
/// `features/reports/presentation/screens/business_dashboard_screen.dart`.
/// This placeholder remains to avoid breaking the shell import.
class DashboardView extends StatelessWidget {
  final dynamic controller;

  const DashboardView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.dashboard_outlined,
      title: 'Dashboard moved',
      subtitle: 'The real-time Business Dashboard is now on the Reports tab.',
    );
  }
}
