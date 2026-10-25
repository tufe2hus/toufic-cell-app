import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../models/daily_profit_entry.dart';
import '../utils/currency_format.dart';

/// Bar chart with one bar per day of a chosen month, showing that day's
/// profit — with a month switcher and a tap-to-inspect breakdown of which
/// products sold that day. Complements [MonthlyProfitChart] (year-over-year
/// monthly totals) by drilling into a single month at day granularity.
class DailyProfitMonthChart extends StatefulWidget {
  const DailyProfitMonthChart({
    super.key,
    required this.entriesForMonth,
    required this.usdToLbpRate,
  });

  /// Returns one [DailyProfitEntry] per day of the month containing
  /// [monthAnchor] (see [AppProvider.dailyProfitForMonth]).
  final List<DailyProfitEntry> Function(DateTime monthAnchor) entriesForMonth;
  /// Admin-configured USD→LBP rate, used to show the Lira equivalent in the
  /// day-detail sheet (see [AppProvider.usdToLbpRate]).
  final double usdToLbpRate;

  static const double _chartHeight = 150;

  @override
  State<DailyProfitMonthChart> createState() => _DailyProfitMonthChartState();
}

class _DailyProfitMonthChartState extends State<DailyProfitMonthChart> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _showDayDetail(DailyProfitEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _DayDetailSheet(entry: entry, usdToLbpRate: widget.usdToLbpRate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entriesForMonth(_month);
    final maxAbsProfit = entries.isEmpty
        ? 0.0
        : entries
              .map((e) => e.profitAfterBills.abs())
              .reduce((a, b) => a > b ? a : b);
    final safeMax = maxAbsProfit <= 0 ? 1.0 : maxAbsProfit;
    final hasData = entries.any((e) => e.profitAfterBills != 0);
    final positiveColor = Colors.green.shade600;
    final negativeColor = Theme.of(context).colorScheme.error;
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

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
                  'Daily profit',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Previous month',
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        DateFormat.yMMMM().format(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Next month',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Profit earned each day this month. Tap a bar to see which products sold that day.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (!hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No profit recorded this month.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in entries)
                      _DayBar(
                        entry: entry,
                        heightFraction: entry.profitAfterBills.abs() / safeMax,
                        maxHeight: DailyProfitMonthChart._chartHeight,
                        color: entry.profitAfterBills >= 0
                            ? positiveColor
                            : negativeColor,
                        currency: currency,
                        onTap: () => _showDayDetail(entry),
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

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.entry,
    required this.heightFraction,
    required this.maxHeight,
    required this.color,
    required this.currency,
    required this.onTap,
  });

  final DailyProfitEntry entry;
  final double heightFraction;
  final double maxHeight;
  final Color color;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActivity = entry.profitAfterBills != 0;
    final barHeight = hasActivity
        ? (heightFraction * maxHeight).clamp(4.0, maxHeight)
        : 2.0;

    return InkWell(
      onTap: hasActivity ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (hasActivity)
              Text(
                currency.format(entry.profitAfterBills),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 4),
            Container(
              width: 18,
              height: barHeight,
              decoration: BoxDecoration(
                color: hasActivity
                    ? color
                    : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.day.day}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  const _DayDetailSheet({required this.entry, required this.usdToLbpRate});

  final DailyProfitEntry entry;
  final double usdToLbpRate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMEEEEd().format(entry.day),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _StatItem(
                  label: 'Sales',
                  value: formatMoney(entry.salesAmount, Currency.usd),
                  secondaryValue: formatLbp(entry.salesAmount, usdToLbpRate),
                ),
                _StatItem(
                  label: 'Profit before bills',
                  value: formatMoney(entry.profitBeforeBills, Currency.usd),
                  secondaryValue: formatLbp(
                    entry.profitBeforeBills,
                    usdToLbpRate,
                  ),
                ),
                _StatItem(
                  label: 'Profit after bills',
                  value: formatMoney(entry.profitAfterBills, Currency.usd),
                  secondaryValue: formatLbp(
                    entry.profitAfterBills,
                    usdToLbpRate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Products sold',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (entry.productSales.isEmpty)
              const Text('No products sold this day.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entry.productSales.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = entry.productSales.entries.elementAt(index);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(product.key),
                      trailing: Text(
                        formatMoney(product.value, Currency.usd),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.secondaryValue,
  });

  final String label;
  final String value;
  final String? secondaryValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (secondaryValue != null)
          Text(
            secondaryValue!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
