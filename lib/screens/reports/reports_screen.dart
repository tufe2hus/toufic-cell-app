import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/currency.dart';
import '../../providers/app_provider.dart';
import '../../utils/currency_format.dart';
import '../../utils/export_utils.dart';
import '../../widgets/daily_profit_month_chart.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/monthly_profit_chart.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/simple_bar_chart.dart';
import '../creditors/creditors_management_screen.dart';
import '../debtors/debtors_management_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(allowAdmin: true, child: _ReportsView());
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');
    final inventoryValue = provider.products.fold<double>(
      0,
      (sum, product) => sum + (product.purchasePrice * product.quantity),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Daily sales',
                  value: currency.format(provider.todaySalesAmount),
                  secondaryValue: formatLbp(
                    provider.todaySalesAmount,
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.today_outlined,
                  colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Weekly sales',
                  value: currency.format(provider.weekSalesAmount),
                  secondaryValue: formatLbp(
                    provider.weekSalesAmount,
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.date_range_outlined,
                  colors: const [Color(0xFF10B981), Color(0xFF047857)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Monthly sales',
                  value: currency.format(provider.monthSalesAmount),
                  secondaryValue: formatLbp(
                    provider.monthSalesAmount,
                    provider.usdToLbpRate,
                  ),
                  subtitle: 'Sales total before expenses or profit',
                  icon: Icons.calendar_month_outlined,
                  colors: const [Color(0xFF14B8A6), Color(0xFF0F766E)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Monthly profit (before bills)',
                  value: currency.format(provider.monthlyProfitBeforeBills),
                  secondaryValue: formatLbp(
                    provider.monthlyProfitBeforeBills,
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.trending_up_outlined,
                  colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Monthly profit (after bills)',
                  value: currency.format(provider.monthlyProfit),
                  secondaryValue: formatLbp(
                    provider.monthlyProfit,
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.trending_down_outlined,
                  colors: const [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Inventory value',
                  value: currency.format(inventoryValue),
                  secondaryValue: formatLbp(
                    inventoryValue,
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.inventory_2_outlined,
                  colors: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                ),
              ),
              SizedBox(
                width: 230,
                child: _TappableMetricCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DebtorsManagementScreen(),
                    ),
                  ),
                  child: MetricCard(
                    title: 'Debtors',
                    value: currency.format(provider.outstandingDebtAmount),
                    secondaryValue: formatLbp(
                      provider.outstandingDebtAmount,
                      provider.usdToLbpRate,
                    ),
                    subtitle: '${provider.pendingDebtors} pending',
                    icon: Icons.people_alt_outlined,
                    colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                  ),
                ),
              ),
              SizedBox(
                width: 230,
                child: _TappableMetricCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreditorsManagementScreen(),
                    ),
                  ),
                  child: MetricCard(
                    title: 'People I owe',
                    value: currency.format(provider.outstandingCreditAmount),
                    secondaryValue: formatLbp(
                      provider.outstandingCreditAmount,
                      provider.usdToLbpRate,
                    ),
                    subtitle: '${provider.pendingCreditors} pending',
                    icon: Icons.handshake_outlined,
                    colors: const [Color(0xFFEC4899), Color(0xFFBE185D)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MonthlyProfitChart(groups: provider.monthlyProfitByYear()),
          const SizedBox(height: 16),
          DailyProfitMonthChart(
            entriesForMonth: provider.dailyProfitForMonth,
            usdToLbpRate: provider.usdToLbpRate,
          ),
          const SizedBox(height: 16),
          const _DailyProfitLookupCard(),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 420,
                child: SimpleBarChart(
                  title: 'Top selling products',
                  values: provider.topSellingProducts(),
                  color: Colors.blue,
                  secondaryLabel: 'Profit',
                  secondaryValues: provider.productProfit(),
                ),
              ),
              SizedBox(
                width: 420,
                child: SimpleBarChart(
                  title: 'Best categories',
                  values: provider.categorySales(),
                  color: Colors.orange,
                  secondaryLabel: 'Profit',
                  secondaryValues: provider.categoryProfit(),
                  onEntryTap: (categoryName) =>
                      _showCategoryDrilldown(context, provider, categoryName),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report exports',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'One Excel workbook with everything: reports summary, transactions, debtors, people you owe, and bills — each on its own sheet.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => _exportExcel(context, provider, inventoryValue),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export Excel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ReportsExportData _buildExportData(AppProvider provider, double inventoryValue) {
    return ReportsExportData(
      dailySales: provider.todaySalesAmount,
      weeklySales: provider.weekSalesAmount,
      monthlySales: provider.monthSalesAmount,
      monthlyProfitBeforeBills: provider.monthlyProfitBeforeBills,
      monthlyProfitAfterBills: provider.monthlyProfit,
      inventoryValue: inventoryValue,
      monthlyProfitSeries: provider.monthlyProfitSeries(),
      topSellingProducts: provider.topSellingProducts(),
      categorySales: provider.categorySales(),
      usdToLbpRate: provider.usdToLbpRate,
      productProfit: provider.productProfit(),
      categoryProfit: provider.categoryProfit(),
    );
  }

  void _showCategoryDrilldown(
    BuildContext context,
    AppProvider provider,
    String categoryName,
  ) {
    final sales = provider.topSalesForCategory(categoryName);
    final totalProfit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(categoryName.isEmpty ? 'General' : categoryName),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top ${sales.length} transaction${sales.length == 1 ? '' : 's'} · '
                  'Total profit ${formatMoney(totalProfit, Currency.usd)}',
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (sales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No transactions recorded for this category yet.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sales.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${sale.productName} ×${sale.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy • HH:mm').format(sale.soldAt),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatMoney(sale.totalAmount, sale.currency),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Profit ${formatMoney(sale.profit, sale.currency)}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportExcel(
    BuildContext context,
    AppProvider provider,
    double inventoryValue,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportFullReportExcel(
        reportData: _buildExportData(provider, inventoryValue),
        transactions: provider.transactions,
        debtors: provider.debtors,
        creditors: provider.creditors,
        bills: provider.bills,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Excel export failed: $error')),
      );
    }
  }
}

class _DailyProfitLookupCard extends StatefulWidget {
  const _DailyProfitLookupCard();

  @override
  State<_DailyProfitLookupCard> createState() =>
      _DailyProfitLookupCardState();
}

class _DailyProfitLookupCardState extends State<_DailyProfitLookupCard> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');
    final snapshot = provider.dailyProfitSnapshot(_selectedDay);
    final now = DateTime.now();
    final isToday =
        _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Daily profit lookup',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDate: _selectedDay,
                    );
                    if (picked != null) {
                      setState(() => _selectedDay = picked);
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    isToday ? 'Today' : DateFormat.yMMMd().format(_selectedDay),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Every day\'s sales and profit stay on record in the database, '
              'so once midnight rolls "today" over to a new day, pick that '
              'date here to see exactly what it was.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _StatColumn(
                  label: 'Sales',
                  value: currency.format(snapshot.salesAmount),
                  secondaryValue: formatLbp(
                    snapshot.salesAmount,
                    provider.usdToLbpRate,
                  ),
                ),
                _StatColumn(
                  label: 'Profit before bills',
                  value: currency.format(snapshot.profitBeforeBills),
                  secondaryValue: formatLbp(
                    snapshot.profitBeforeBills,
                    provider.usdToLbpRate,
                  ),
                ),
                _StatColumn(
                  label: 'Profit after bills',
                  value: currency.format(snapshot.profitAfterBills),
                  secondaryValue: formatLbp(
                    snapshot.profitAfterBills,
                    provider.usdToLbpRate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a [MetricCard] so tapping it navigates elsewhere, e.g. to the
/// Debtors or People I Owe screens.
class _TappableMetricCard extends StatelessWidget {
  const _TappableMetricCard({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.secondaryValue,
  });

  final String label;
  final String value;
  final String secondaryValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          secondaryValue,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
