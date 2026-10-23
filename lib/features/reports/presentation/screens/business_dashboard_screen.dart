import 'package:flutter/material.dart';
import '../../presentation/controllers/report_controller.dart';
import '../../domain/report_models.dart';

class BusinessDashboardScreen extends StatefulWidget {
  final ReportController? controller;
  final ValueChanged<int>? onNavigateToTab;

  const BusinessDashboardScreen({
    super.key,
    this.controller,
    this.onNavigateToTab,
  });

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  bool _isLoading = false;

  // ── Shell page indexes ──
  static const int _tabInventory = 3;
  static const int _tabCustomers = 5;
  static const int _tabSuppliers = 6;
  static const int _tabAccounts = 7;

  String _formatCurrency(num amount) {
    final double val = amount.toDouble();
    final String fixed = val.toStringAsFixed(2);
    final parts = fixed.split('.');
    final String intPart = parts[0];
    final String decPart = parts[1];

    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (intPart[i] == '-') {
        buffer.write('-');
        continue;
      }
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
      count++;
    }
    final String formattedInt = buffer.toString().split('').reversed.join('');
    return 'PKR $formattedInt.$decPart';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoad();
    });
  }

  Future<void> _initialLoad() async {
    if (widget.controller == null) return;
    await widget.controller?.loadMetrics();
  }

  void _refreshData() {
    setState(() => _isLoading = true);
    widget.controller?.loadMetrics();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _navigateTo(int tabIndex) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigation handler not wired to Shell.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────
  //  KPI BREAKDOWN DIALOG — Shows filtered details for the clicked card
  // ───────────────────────────────────────────────────────────────────
  void _showKpiBreakdownDialog({
    required String title,
    required IconData icon,
    required Color color,
    required KpiFilterType type,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => KpiBreakdownDialog(
        title: title,
        icon: icon,
        color: color,
        type: type,
        controller: widget.controller!,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F7F9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Loading Business Dashboard...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller ?? ChangeNotifier(),
      builder: (context, _) {
        final ctrl = widget.controller;

        if (ctrl == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F7F9),
            body: Center(
                child: Text('No report controller supplied to Dashboard.')),
          );
        }

        if (ctrl.metrics == null) {
          return _buildLoadingState();
        }

        final metrics = ctrl.metrics!;

        final double todayRevenue = metrics.todayRevenue.paisa / 100.0;
        final double monthRevenue = metrics.monthRevenue.paisa / 100.0;
        final double monthPurchases = metrics.monthPurchases.paisa / 100.0;
        final double monthExpenses = metrics.monthExpenses.paisa / 100.0;
        final double monthProfit = metrics.monthProfit.paisa / 100.0;
        final double stockValue = metrics.stockValue.paisa / 100.0;

        final double receivables = metrics.totalReceivables.paisa / 100.0;
        final double payables = metrics.totalPayables.paisa / 100.0;
        final double netPosition =
            (metrics.totalReceivables.paisa - metrics.totalPayables.paisa) /
                100.0;

        final int totalMedicines = metrics.totalMedicines;
        final int lowStockItems = metrics.lowStockCount;
        final int expiringSoonItems = metrics.expiringSoonCount;
        final int expiredItems = metrics.expiredCount;

        final List<DailyTrend> salesTrend = metrics.salesTrend;
        final List<CategoryBreakdown> topSelling = metrics.topSelling;

        return Container(
          color: const Color(0xFFF4F7F9),
          child: SelectionArea(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Section ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded,
                              color: Color(0xFF10B981), size: 32),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Business Dashboard',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                      letterSpacing: -0.5)),
                              SizedBox(height: 2),
                              Text(
                                  'Real-time pharmacy performance overview. Click any KPI for details.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _refreshData,
                        icon: _isLoading
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF10B981)))
                            : const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── KPI Grid (ALL CLICKABLE) ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 6;
                      if (constraints.maxWidth < 1024) crossAxisCount = 3;
                      if (constraints.maxWidth < 600) crossAxisCount = 2;

                      const double spacing = 16.0;
                      final double cardWidth = (constraints.maxWidth -
                          (spacing * (crossAxisCount - 1))) /
                          crossAxisCount;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          _buildMiniKpiCard(
                            width: cardWidth,
                            title: 'TODAY REVENUE',
                            value: _formatCurrency(todayRevenue),
                            trendText: 'Click for breakdown',
                            isUp: true,
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => _showKpiBreakdownDialog(
                              title: 'Today Revenue',
                              icon: Icons.payments_rounded,
                              color: const Color(0xFF10B981),
                              type: KpiFilterType.todayRevenue,
                            ),
                          ),
                          _buildMiniKpiCard(
                            width: cardWidth,
                            title: 'MONTH REVENUE',
                            value: _formatCurrency(monthRevenue),
                            trendText: 'Click for breakdown',
                            isUp: true,
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF3B82F6),
                            onTap: () => _showKpiBreakdownDialog(
                              title: 'Month Revenue',
                              icon: Icons.trending_up_rounded,
                              color: const Color(0xFF3B82F6),
                              type: KpiFilterType.monthRevenue,
                            ),
                          ),
                          _buildMiniKpiCard(
                            width: cardWidth,
                            title: 'MONTH PURCHASES',
                            value: _formatCurrency(monthPurchases),
                            trendText: 'Click for breakdown',
                            isUp: false,
                            icon: Icons.shopping_bag_rounded,
                            color: const Color(0xFF8B5CF6),
                            onTap: () => _showKpiBreakdownDialog(
                              title: 'Month Purchases',
                              icon: Icons.shopping_bag_rounded,
                              color: const Color(0xFF8B5CF6),
                              type: KpiFilterType.monthPurchases,
                            ),
                          ),
                          _buildMiniKpiCard(
                            width: cardWidth,
                            title: 'MONTH EXPENSES',
                            value: _formatCurrency(monthExpenses),
                            trendText: 'Click for breakdown',
                            isUp: false,
                            icon: Icons.sell_rounded,
                            color: const Color(0xFFF97316),
                            onTap: () => _showKpiBreakdownDialog(
                              title: 'Month Expenses',
                              icon: Icons.sell_rounded,
                              color: const Color(0xFFF97316),
                              type: KpiFilterType.monthExpenses,
                            ),
                          ),
                          _buildMiniKpiCard(
                            width: cardWidth,
                            title: 'MONTH PROFIT',
                            value: _formatCurrency(monthProfit),
                            trendText: 'Click for breakdown',
                            isUp: monthProfit >= 0,
                            icon: Icons.show_chart_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => _showKpiBreakdownDialog(
                              title: 'Month Profit',
                              icon: Icons.show_chart_rounded,
                              color: const Color(0xFF10B981),
                              type: KpiFilterType.monthProfit,
                            ),
                          ),
                          _buildMiniKpiCard(
                            width: cardWidth,
                            title: 'STOCK VALUE',
                            value: _formatCurrency(stockValue),
                            trendText: 'Click for breakdown',
                            isUp: true,
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFF3B82F6),
                            onTap: () => _showKpiBreakdownDialog(
                              title: 'Stock Value',
                              icon: Icons.inventory_2_rounded,
                              color: const Color(0xFF3B82F6),
                              type: KpiFilterType.stockValue,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 1024;
                      return Flex(
                        direction:
                        isDesktop ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: isDesktop ? 1 : 0,
                              child: _buildFinancialAttentionCard(
                                  receivables, payables, netPosition)),
                          if (isDesktop) const SizedBox(width: 20),
                          if (!isDesktop) const SizedBox(height: 20),
                          Expanded(
                              flex: isDesktop ? 1 : 0,
                              child: _buildStockAlertsCard(
                                  totalMedicines,
                                  lowStockItems,
                                  expiringSoonItems,
                                  expiredItems)),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 1024;
                      return Flex(
                        direction:
                        isDesktop ? Axis.horizontal : Axis.vertical,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: isDesktop ? 1 : 0,
                              child: _buildSalesTrendCard(salesTrend)),
                          if (isDesktop) const SizedBox(width: 20),
                          if (!isDesktop) const SizedBox(height: 20),
                          Expanded(
                              flex: isDesktop ? 1 : 0,
                              child: _buildTopSellingCard(topSelling)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── KPI Mini Card — NOW CLICKABLE ──
  Widget _buildMiniKpiCard({
    required double width,
    required String title,
    required String value,
    required String trendText,
    required bool isUp,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: width,
      height: 135,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onTap != null
              ? color.withOpacity(0.25)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              if (onTap != null)
                Icon(Icons.open_in_new_rounded,
                    size: 14, color: color.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                  isUp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(trendText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8))),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withOpacity(0.04),
        splashColor: color.withOpacity(0.08),
        child: card,
      ),
    );
  }

  Widget _buildFinancialAttentionCard(
      double receivables, double payables, double netPosition) {
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_rounded,
      iconBgColor: const Color(0xFF10B981),
      title: 'Financial Attention',
      subtitle: 'Receivables, payables and net position at a glance',
      child: Column(
        children: [
          _buildListRow(
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            title: 'Receivables (Customers)',
            subtitle: 'Pending customer payments',
            value: _formatCurrency(receivables),
            valueColor: const Color(0xFF10B981),
            onTap: () => _navigateTo(_tabCustomers),
            showArrow: true,
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          _buildListRow(
            icon: Icons.outbox_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFEE2E2),
            title: 'Payables (Suppliers)',
            subtitle: 'Amount due to suppliers',
            value: _formatCurrency(payables),
            valueColor: const Color(0xFFEF4444),
            onTap: () => _navigateTo(_tabSuppliers),
            showArrow: true,
          ),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          _buildListRow(
            icon: Icons.insert_chart_rounded,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFFDBEAFE),
            title: 'Net Position',
            subtitle: 'Overall financial position',
            value: _formatCurrency(netPosition),
            valueColor: netPosition >= 0
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            onTap: () => _navigateTo(_tabAccounts),
            showArrow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertsCard(
      int totalMedicines, int lowStock, int expiringSoon, int expired) {
    return _buildSectionCard(
      icon: Icons.notifications_active_rounded,
      iconBgColor: const Color(0xFFEF4444),
      title: 'Stock Alerts',
      subtitle: 'Items that need your attention',
      actionText: 'View All →',
      onActionTap: () => _navigateTo(_tabInventory),
      child: Column(
        children: [
          _buildAlertRow(
              dotColor: const Color(0xFF10B981),
              label: 'Total Medicines',
              count: '$totalMedicines',
              countColor: const Color(0xFF10B981),
              countBg: const Color(0xFFD1FAE5),
              onTap: () => _navigateTo(_tabInventory)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          _buildAlertRow(
              dotColor: const Color(0xFFF59E0B),
              label: 'Low Stock Items',
              count: '$lowStock',
              countColor: const Color(0xFFF59E0B),
              countBg: const Color(0xFFFEF3C7),
              onTap: () => _navigateTo(_tabInventory)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          _buildAlertRow(
              dotColor: const Color(0xFFEF4444),
              label: 'Expiring Soon (90d)',
              count: '$expiringSoon',
              countColor: const Color(0xFFEF4444),
              countBg: const Color(0xFFFEE2E2),
              onTap: () => _navigateTo(_tabInventory)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          _buildAlertRow(
              dotColor: const Color(0xFFDC2626),
              label: 'Expired',
              count: '$expired',
              countColor: const Color(0xFFEF4444),
              countBg: const Color(0xFFFEE2E2),
              onTap: () => _navigateTo(_tabInventory)),
        ],
      ),
    );
  }

  Widget _buildSalesTrendCard(List<DailyTrend> chartData) {
    return _buildSectionCard(
      icon: Icons.trending_up_rounded,
      iconBgColor: const Color(0xFF10B981),
      title: 'Sales Trend (Net of Returns)',
      subtitle: 'Chronological sales performance',
      actionWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: const [
            Icon(Icons.calendar_today_rounded,
                size: 12, color: Color(0xFF64748B)),
            SizedBox(width: 6),
            Text('Daily revenue trends',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
          ],
        ),
      ),
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _MainSalesChartPainter(dataPoints: chartData),
          child: Container(),
        ),
      ),
    );
  }

  Widget _buildTopSellingCard(List<CategoryBreakdown> rawTopItems) {
    final iconColors = [
      const Color(0xFF3B82F6),
      const Color(0xFFF97316),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];

    return _buildSectionCard(
      icon: Icons.shopping_cart_rounded,
      iconBgColor: const Color(0xFF14B8A6),
      title: 'Top Items (This Month)',
      subtitle: 'Best performing products — net of returns',
      padding: EdgeInsets.zero,
      child: rawTopItems.isEmpty
          ? const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
            child: Text('No recorded sales this month.',
                style: TextStyle(color: Color(0xFF94A3B8)))),
      )
          : Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)))),
            child: Row(
              children: const [
                SizedBox(
                    width: 24,
                    child: Text('#',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)))),
                Expanded(
                    child: Text('Item',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)))),
                SizedBox(
                    width: 80,
                    child: Text('Net Qty',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)))),
                SizedBox(
                    width: 100,
                    child: Text('Net Revenue',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)))),
              ],
            ),
          ),
          ...rawTopItems.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final String name = item.name;
            final String qty = item.quantity.toString();
            final double revNum = item.revenue.paisa / 100.0;
            final c = iconColors[idx % iconColors.length];

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9)))),
              child: Row(
                children: [
                  SizedBox(
                      width: 24,
                      child: Text('${idx + 1}.',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B)))),
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                        border: Border.all(color: c, width: 3),
                        shape: BoxShape.circle),
                  ),
                  Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis)),
                  SizedBox(
                      width: 80,
                      child: Text(qty,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 100,
                      child: Text(_formatCurrency(revNum),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981)))),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onActionTap,
    Widget? actionWidget,
    Widget? child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
                if (actionText != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onActionTap,
                      borderRadius: BorderRadius.circular(20),
                      hoverColor: const Color(0xFFF1F5F9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color:
                              const Color(0xFF10B981).withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          actionText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  actionWidget ?? const SizedBox.shrink(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (child != null) Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  Widget _buildListRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    final rowChild = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor)),
        if (showArrow) ...[
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: Color(0xFFCBD5E1)),
        ],
      ],
    );

    if (onTap == null) {
      return rowChild;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: rowChild,
      ),
    );
  }

  Widget _buildAlertRow({
    required Color dotColor,
    required String label,
    required String count,
    required Color countColor,
    required Color countBg,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569)))),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                  color: countBg, borderRadius: BorderRadius.circular(10)),
              child: Text(count,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: countColor)),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
//  KPI FILTER TYPE
// ──────────────────────────────────────────────────────────────────────
enum KpiFilterType {
  todayRevenue,
  monthRevenue,
  monthPurchases,
  monthExpenses,
  monthProfit,
  stockValue,
}

// ──────────────────────────────────────────────────────────────────────
//  KPI BREAKDOWN DIALOG
// ──────────────────────────────────────────────────────────────────────
class KpiBreakdownDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final KpiFilterType type;
  final ReportController controller;

  const KpiBreakdownDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.type,
    required this.controller,
  });

  @override
  State<KpiBreakdownDialog> createState() => _KpiBreakdownDialogState();
}

class _KpiBreakdownDialogState extends State<KpiBreakdownDialog> {
  bool _isLoading = true;
  List<BreakdownRow> _rows = [];
  String _totalLabel = 'Total';
  String _totalValue = 'PKR 0.00';
  String _subtitle = '';

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  String _formatMoney(num rupees) {
    final fixed = rupees.toStringAsFixed(2);
    final parts = fixed.split('.');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (parts[0][i] == '-') {
        buffer.write('-');
        continue;
      }
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(parts[0][i]);
      count++;
    }
    return 'PKR ${buffer.toString().split('').reversed.join('')}.${parts[1]}';
  }

  Future<void> _loadBreakdown() async {
    final metrics = widget.controller.metrics;
    if (metrics == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Trigger report generation for the right type based on KPI
    ReportType reportType;
    ReportFilter filter;
    final now = DateTime.now();

    switch (widget.type) {
      case KpiFilterType.todayRevenue:
        reportType = ReportType.sales;
        filter = ReportFilter(
          fromDate: DateTime(now.year, now.month, now.day),
          toDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        _subtitle = 'Today\'s sales invoices (net of returns)';
        _totalLabel = 'Today Revenue';
        _totalValue = _formatMoney(metrics.todayRevenue.paisa / 100.0);
        break;

      case KpiFilterType.monthRevenue:
        reportType = ReportType.sales;
        filter = ReportFilter.thisMonth();
        _subtitle = 'This month\'s sales invoices (net of returns)';
        _totalLabel = 'Month Revenue';
        _totalValue = _formatMoney(metrics.monthRevenue.paisa / 100.0);
        break;

      case KpiFilterType.monthPurchases:
        reportType = ReportType.purchases;
        filter = ReportFilter.thisMonth();
        _subtitle = 'This month\'s purchase invoices (net of returns)';
        _totalLabel = 'Month Purchases';
        _totalValue = _formatMoney(metrics.monthPurchases.paisa / 100.0);
        break;

      case KpiFilterType.monthProfit:
        reportType = ReportType.profit;
        filter = ReportFilter.thisMonth();
        _subtitle = 'This month\'s profit per medicine';
        _totalLabel = 'Month Profit';
        _totalValue = _formatMoney(metrics.monthProfit.paisa / 100.0);
        break;

      case KpiFilterType.stockValue:
        reportType = ReportType.inventory;
        filter = ReportFilter.thisMonth();
        _subtitle = 'Current inventory valuation';
        _totalLabel = 'Stock Value';
        _totalValue = _formatMoney(metrics.stockValue.paisa / 100.0);
        break;

      case KpiFilterType.monthExpenses:
      // No dedicated expense report — show summary only
        setState(() {
          _isLoading = false;
          _totalLabel = 'Month Expenses';
          _totalValue = _formatMoney(metrics.monthExpenses.paisa / 100.0);
          _subtitle = 'Operational spending this month';
          _rows = [];
        });
        return;
    }

    // Fetch report data
    final result = await widget.controller.exportReportData(reportType, filter);
    if (!mounted) return;

    setState(() {
      _rows = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width > 900 ? 820.0 : size.width * 0.92;
    final dialogHeight = size.height * 0.78;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                    Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(_subtitle,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            // Total card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: widget.color, size: 18),
                    const SizedBox(width: 10),
                    Text('$_totalLabel: ',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                    Text(_totalValue,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: widget.color)),
                  ],
                ),
              ),
            ),

            // Rows
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No detailed breakdown available',
                        style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13)),
                  ],
                ),
              )
                  : Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFE2E8F0)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (ctx, i) {
                    final row = _rows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text('${i + 1}.',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight:
                                    FontWeight.w600)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(row.primary,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                        FontWeight.w700,
                                        color:
                                        Color(0xFF0F172A))),
                                if (row.secondary.isNotEmpty)
                                  Padding(
                                    padding:
                                    const EdgeInsets.only(
                                        top: 2),
                                    child: Text(row.secondary,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(
                                                0xFF94A3B8))),
                                  ),
                              ],
                            ),
                          ),
                          Text(row.amount,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: widget.color)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow {
  final String primary;
  final String secondary;
  final String amount;
  const _BreakdownRow({
    required this.primary,
    required this.secondary,
    required this.amount,
  });
}

// ── Chart Painter ──
class _MainSalesChartPainter extends CustomPainter {
  final List<DailyTrend> dataPoints;
  _MainSalesChartPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    const textStyle = TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 10,
        fontWeight: FontWeight.w600);
    const double leftPadding = 65.0;
    const double bottomPadding = 20.0;
    final double graphWidth = size.width - leftPadding;
    final double graphHeight = size.height - bottomPadding;

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double maxPaisa = 1000.0 * 100.0;
    for (final dp in dataPoints) {
      if (dp.revenue.paisa > maxPaisa) maxPaisa = dp.revenue.paisa.toDouble();
    }
    final double maxRupees = maxPaisa / 100.0;

    String formatVal(double rupees) {
      if (rupees >= 1000.0) {
        return 'PKR ${(rupees / 1000.0).toStringAsFixed(1)}k';
      }
      return 'PKR ${rupees.toStringAsFixed(0)}';
    }

    const int gridLinesCount = 4;
    for (int i = 0; i < gridLinesCount; i++) {
      final double fraction = i / (gridLinesCount - 1);
      final double y = fraction * graphHeight;
      final double valueAtY = maxRupees * (1.0 - fraction);

      final tp = TextPainter(
          text: TextSpan(text: formatVal(valueAtY), style: textStyle),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 10, y - 6));

      if (i < gridLinesCount - 1) {
        canvas.drawLine(
            Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      }
    }

    if (dataPoints.isEmpty) return;

    final int pointsCount = dataPoints.length;
    final double xSpacing =
    pointsCount > 1 ? graphWidth / (pointsCount - 1) : graphWidth;

    final List<Offset> points = [];
    for (int i = 0; i < pointsCount; i++) {
      final dp = dataPoints[i];
      final x = leftPadding + (i * xSpacing);
      final double ratio =
      maxPaisa > 0 ? dp.revenue.paisa / maxPaisa : 0.0;
      final y = graphHeight - (ratio * graphHeight);
      points.add(Offset(x, y));

      final tp = TextPainter(
          text: TextSpan(text: dp.dateLabel, style: textStyle),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - (tp.width / 2), graphHeight + 8));
    }

    const lineColor = Color(0xFF10B981);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withOpacity(0.25), lineColor.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(leftPadding, 0, graphWidth, graphHeight))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    if (points.isNotEmpty) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, graphHeight)
        ..lineTo(points.first.dx, graphHeight)
        ..close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      for (var point in points) {
        canvas.drawCircle(point, 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MainSalesChartPainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints;
}