import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Vertical bar chart showing profit earned per month, grouped by year
/// (oldest year first), with a year label to the left of each group.
class MonthlyProfitChart extends StatelessWidget {
  const MonthlyProfitChart({super.key, required this.groups});

  /// Year-grouped monthly profit, oldest year first; each group's month map
  /// is ordered oldest to newest (e.g. "Mar" -> profit, ..., "Aug" -> profit).
  final List<({int year, Map<String, double> months})> groups;

  static const double _chartHeight = 150;
  static const double _columnHeight = _chartHeight + 52;

  @override
  Widget build(BuildContext context) {
    final allValues = groups.expand((group) => group.months.values).toList();
    final currency = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final maxValue = allValues.isEmpty
        ? 0.0
        : allValues.map((value) => value.abs()).reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final hasData = allValues.isNotEmpty && maxValue != 0;
    final positiveColor = Colors.green.shade600;
    final negativeColor = Theme.of(context).colorScheme.error;

    Widget bar(String label, double value) {
      final isProfit = value >= 0;
      final barHeight = ((value.abs() / safeMax) * _chartHeight).clamp(
        4.0,
        _chartHeight,
      );
      return SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              currency.format(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: barHeight,
              decoration: BoxDecoration(
                color: isProfit ? positiveColor : negativeColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    Widget yearLabel(int year) {
      return Container(
        width: 36,
        height: _columnHeight,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.only(right: 10),
        alignment: Alignment.bottomLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            '$year',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly profit',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Profit earned each month, grouped by year, based on completed sales.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (!hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No profit recorded yet.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: _columnHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final group in groups) ...[
                        yearLabel(group.year),
                        for (final entry in group.months.entries)
                          bar(entry.key, entry.value),
                        const SizedBox(width: 16),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
