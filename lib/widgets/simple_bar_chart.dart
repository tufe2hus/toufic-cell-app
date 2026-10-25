import 'package:flutter/material.dart';

import '../models/currency.dart';

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.title,
    required this.values,
    required this.color,
    this.secondaryLabel,
    this.secondaryValues,
    this.onEntryTap,
  });

  final String title;
  final Map<String, double> values;
  final Color color;
  /// Label for the extra figure shown under each bar, e.g. "Profit".
  final String? secondaryLabel;
  /// Keyed the same way as [values] — shown as a small "label: amount" line
  /// under the matching bar when provided (e.g. category profit alongside
  /// category sales).
  final Map<String, double>? secondaryValues;
  /// Called with a bar's key (e.g. category or product name) when tapped —
  /// lets the caller drill down into that entry's detail.
  final ValueChanged<String>? onEntryTap;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.take(5).toList();
    final maxValue = entries.isEmpty
        ? 1.0
        : entries.map((entry) => entry.value).reduce((a, b) => a > b ? a : b);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No chart data available yet.'),
              )
            else
              ...entries.map((entry) {
                final fraction = maxValue == 0 ? 0.0 : entry.value / maxValue;
                final secondary = secondaryValues?[entry.key];
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text(formatMoney(entry.value, Currency.usd)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: fraction,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.12),
                      ),
                    ),
                    if (secondary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${secondaryLabel ?? 'Secondary'}: ${formatMoney(secondary, Currency.usd)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: onEntryTap == null
                      ? content
                      : InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onEntryTap!(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: content,
                          ),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
