import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/currency.dart';
import '../../models/stock_intake_model.dart';
import '../../providers/app_provider.dart';
import '../../utils/currency_format.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/role_guard.dart';

/// Shows what new stock was brought into the store and when — the only
/// history of restocks/new products, since a product's own `quantity` field
/// only ever holds its current total (see AppProvider.saveProduct, which is
/// what actually writes the underlying [StockIntake] records).
class StockIntakeScreen extends StatelessWidget {
  const StockIntakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(allowAdmin: true, child: _StockIntakeView());
  }
}

class _StockIntakeView extends StatefulWidget {
  const _StockIntakeView();

  @override
  State<_StockIntakeView> createState() => _StockIntakeViewState();
}

class _StockIntakeViewState extends State<_StockIntakeView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final now = DateTime.now();
    final today = provider.stockIntakes.where(
      (intake) =>
          intake.createdAt.year == now.year &&
          intake.createdAt.month == now.month &&
          intake.createdAt.day == now.day,
    );
    final entries = provider.stockIntakeForMonth(_month);
    final unitsToday = today.fold<int>(0, (sum, i) => sum + i.quantityAdded);
    final unitsThisMonth = entries.fold<int>(0, (sum, i) => sum + i.quantityAdded);
    final costsByCurrency = <Currency, double>{};
    for (final intake in entries) {
      costsByCurrency[intake.currency] =
          (costsByCurrency[intake.currency] ?? 0) + intake.totalCost;
    }
    final usdCost = costsByCurrency[Currency.usd] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Goods brought in')),
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
                  title: 'Units added today',
                  value: unitsToday.toString(),
                  icon: Icons.today_outlined,
                  colors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Units added this month',
                  value: unitsThisMonth.toString(),
                  icon: Icons.move_to_inbox_outlined,
                  colors: const [Color(0xFF10B981), Color(0xFF047857)],
                ),
              ),
              SizedBox(
                width: 230,
                child: MetricCard(
                  title: 'Cost this month',
                  value: formatMoney(usdCost, Currency.usd),
                  secondaryValue: formatLbp(usdCost, provider.usdToLbpRate),
                  icon: Icons.payments_outlined,
                  colors: const [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
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
                        'Goods brought in this month',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                    'Every new product and every restock is logged here '
                    'automatically when you add or edit a product with a '
                    'higher quantity — nothing to fill in separately.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No stock was brought in this month.'),
                      ),
                    )
                  else
                    ...entries.map((intake) => _StockIntakeTile(intake: intake)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockIntakeTile extends StatelessWidget {
  const _StockIntakeTile({required this.intake});

  final StockIntake intake;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: intake.isNewProduct
            ? Colors.green.shade100
            : Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          intake.isNewProduct
              ? Icons.new_releases_outlined
              : Icons.move_to_inbox_outlined,
          color: intake.isNewProduct ? Colors.green.shade800 : null,
          size: 20,
        ),
      ),
      title: Text(
        '${intake.productName} · +${intake.quantityAdded}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${intake.categoryName.isEmpty ? 'General' : intake.categoryName} • '
            '${intake.isNewProduct ? 'New product' : 'Restock'}',
          ),
          Text(
            DateFormat('dd/MM/yyyy • HH:mm').format(intake.createdAt),
          ),
          if (intake.createdBy.isNotEmpty)
            Text(
              'By: ${intake.createdBy}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatMoney(intake.totalCost, intake.currency),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${formatMoney(intake.purchasePrice, intake.currency)} / unit',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
