import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/business_record_models.dart';
import '../../models/cart_item.dart';
import '../../models/currency.dart';
import '../../models/product_model.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/contacts_picker.dart';
import '../../utils/currency_format.dart';
import '../../utils/export_utils.dart';
import '../../utils/phone_normalization.dart';
import '../../utils/whatsapp_utils.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/metric_card.dart';

class DebtorsManagementScreen extends StatefulWidget {
  const DebtorsManagementScreen({super.key});

  @override
  State<DebtorsManagementScreen> createState() =>
      _DebtorsManagementScreenState();
}

class _DebtorsManagementScreenState extends State<DebtorsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  Currency? _currencyFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCurrencyFilter(Currency currency) {
    setState(() {
      _currencyFilter = _currencyFilter == currency ? null : currency;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filtered = provider.debtors.where((debtor) {
      final matchesQuery =
          query.isEmpty ||
          debtor.name.toLowerCase().contains(query) ||
          debtor.phoneNumber.toLowerCase().contains(query);
      final matchesCurrency = switch (_currencyFilter) {
        null => true,
        Currency.usd => debtor.hasUsdActivity,
        Currency.lbp => debtor.hasLbpActivity,
      };
      return matchesQuery && matchesCurrency;
    }).toList();
    final activeDebtors = filtered
        .where((debtor) => !debtor.isSettled)
        .toList();
    final paidDebtors = filtered.where((debtor) => debtor.isSettled).toList();

    final totalUsdDebt = provider.debtors.fold<double>(
      0,
      (sum, debtor) => sum + debtor.usdRemainingAmount,
    );
    final totalLbpDebt = provider.debtors.fold<double>(
      0,
      (sum, debtor) => sum + debtor.lbpRemainingAmount,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Debtors management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.currentUser != null
            ? () => _showAddDebtorDialog(context, provider)
            : null,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('New debtor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 250,
                child: MetricCard(
                  title: 'Number of debtors',
                  value: provider.pendingDebtors.toString(),
                  icon: Icons.people_alt_outlined,
                  colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
              ),
              SizedBox(
                width: 250,
                child: _TappableMetricCard(
                  selected: _currencyFilter == Currency.usd,
                  onTap: () => _toggleCurrencyFilter(Currency.usd),
                  child: MetricCard(
                    title: 'Remaining USD debt',
                    value: formatMoney(totalUsdDebt, Currency.usd),
                    secondaryValue: formatLbp(totalUsdDebt, provider.usdToLbpRate),
                    subtitle: 'Tap to filter',
                    icon: Icons.attach_money_rounded,
                    colors: const [Color(0xFFF97316), Color(0xFFEA580C)],
                  ),
                ),
              ),
              SizedBox(
                width: 250,
                child: _TappableMetricCard(
                  selected: _currencyFilter == Currency.lbp,
                  onTap: () => _toggleCurrencyFilter(Currency.lbp),
                  child: MetricCard(
                    title: 'Remaining LBP debt',
                    value: formatMoney(totalLbpDebt, Currency.lbp),
                    subtitle: 'Tap to filter',
                    icon: Icons.account_balance_wallet_outlined,
                    colors: const [Color(0xFFA855F7), Color(0xFF7E22CE)],
                  ),
                ),
              ),
            ],
          ),
          if (provider.isAdmin) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await exportDebtorsExcel(provider.debtors);
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Excel export failed: $error')),
                      );
                    }
                  },
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export debtors to Excel'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await _showDebtorCopyReport(context, provider.debtors);
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Deptors'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search customer or phone number',
            ),
          ),
          if (_currencyFilter != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(
                  'Showing ${_currencyFilter == Currency.usd ? 'USD' : 'LBP'}-owing debtors only',
                ),
                onDeleted: () => setState(() => _currencyFilter = null),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (activeDebtors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active debtor records found.'),
              ),
            )
          else
            ...activeDebtors.map(
              (debtor) => _DebtorTile(
                debtor: debtor,
                usdToLbpRate: provider.usdToLbpRate,
                onPartialPayment: (currency) =>
                    _showPaymentDialog(context, provider, debtor, currency),
                onFullPayment: (currency) =>
                    _recordFullPayment(context, provider, debtor, currency),
                onHistory: () => _showHistoryDialog(context, provider, debtor),
                onAddCharge: () => _startCharge(context, debtor),
                onDelete: provider.isAdmin
                    ? () => _deleteDebtor(context, provider, debtor)
                    : null,
              ),
            ),
          if (paidDebtors.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Paid/Completed',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...paidDebtors.map(
              (debtor) => _DebtorTile(
                debtor: debtor,
                usdToLbpRate: provider.usdToLbpRate,
                onPartialPayment: (currency) =>
                    _showPaymentDialog(context, provider, debtor, currency),
                onFullPayment: (currency) =>
                    _recordFullPayment(context, provider, debtor, currency),
                onHistory: () => _showHistoryDialog(context, provider, debtor),
                onAddCharge: () => _startCharge(context, debtor),
                onDelete: provider.isAdmin
                    ? () => _deleteDebtor(context, provider, debtor)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDebtorCopyReport(
    BuildContext context,
    List<Debtor> debtors,
  ) async {
    final message = buildDebtorReportMessage(debtors);
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Debtors report'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(message),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(false);
              }
              if (context.mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Debtors report copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy report'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDebtorDialog(
    BuildContext context,
    AppProvider provider,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AddDebtorDialog(provider: provider),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _showPaymentDialog(
    BuildContext context,
    AppProvider provider,
    Debtor debtor,
    Currency currency,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSubmitting = false;
    final remaining = currency == Currency.usd
        ? debtor.usdRemainingAmount
        : debtor.lbpRemainingAmount;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Partial payment for ${debtor.name} (${currency.symbol})',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Remaining: ${formatMoney(remaining, currency)}'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Paid amount (${currency.symbol})',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final amount =
                              double.tryParse(amountController.text.trim()) ??
                              0;
                          if (amount <= 0) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Payment amount must be greater than zero.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (amount > remaining + 0.009) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Payment cannot exceed remaining debt '
                                  '(${formatMoney(remaining, currency)}).',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => isSubmitting = true);
                          final payment = PaymentRecord(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            debtorId: debtor.id,
                            customerName: debtor.name,
                            amount: amount,
                            note: noteController.text.trim(),
                            receivedBy:
                                provider.currentUser?.email ?? 'Unknown',
                            paidAt: DateTime.now(),
                            paymentMethod: 'cash',
                            status: 'completed',
                            currency: currency,
                          );
                          try {
                            await provider.recordPayment(
                              payment,
                              debtor,
                              currency: currency,
                            );
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Payment recorded successfully.'),
                              ),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to record payment: $error',
                                ),
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setState(() => isSubmitting = false);
                            }
                          }
                        },
                  child: const Text('Record payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _recordFullPayment(
    BuildContext context,
    AppProvider provider,
    Debtor debtor,
    Currency currency,
  ) async {
    final remaining = currency == Currency.usd
        ? debtor.usdRemainingAmount
        : debtor.lbpRemainingAmount;
    if (remaining <= 0) {
      return;
    }
    final payment = PaymentRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      debtorId: debtor.id,
      customerName: debtor.name,
      amount: remaining,
      note: 'Full payment',
      receivedBy: provider.currentUser?.email ?? 'Unknown',
      paidAt: DateTime.now(),
      currency: currency,
    );
    try {
      await provider.recordPayment(payment, debtor, currency: currency);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${debtor.name} is fully paid in ${currency.symbol}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record full payment: $error')),
        );
      }
    }
  }

  Future<void> _deleteDebtor(
    BuildContext context,
    AppProvider provider,
    Debtor debtor,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete ${debtor.name}?',
      message:
          'This permanently deletes this debtor and their full history from '
          'the database and restores any products they took on debt back to '
          'stock. No balance calculation is performed. This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteDebtor(debtor);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${debtor.name}.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete debtor: $error')),
        );
      }
    }
  }

  /// Starts a "charge to this debtor" cart session and pops back to the
  /// store dashboard, which switches to the Products tab so the products
  /// picked next get added straight to [debtor]'s balance (see
  /// [CartProvider.startChargeFor] and the `_openDebtors` call site in
  /// StoreDashboardScreen).
  void _startCharge(BuildContext context, Debtor debtor) {
    context.read<CartProvider>().startChargeFor(
      DebtorChargeTarget(
        id: debtor.id,
        name: debtor.name,
        phone: debtor.phoneNumber,
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _showHistoryDialog(
    BuildContext context,
    AppProvider provider,
    Debtor debtor,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('History – ${debtor.name}'),
          content: SizedBox(
            width: 480,
            child: StreamBuilder<List<DebtorTransaction>>(
              stream: provider.debtorTransactionsStream(debtor.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load history: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Text('No transactions recorded yet.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _HistoryTile(entry: items[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// Wraps a [MetricCard] so it can act as a filter toggle, with a ring
/// highlight while its filter is active.
class _TappableMetricCard extends StatelessWidget {
  const _TappableMetricCard({
    required this.child,
    required this.onTap,
    required this.selected,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                )
              : null,
          child: child,
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final DebtorTransaction entry;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd/MM/yyyy • HH:mm').format(entry.createdAt);
    if (entry.isPayment) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.payments_outlined, color: Colors.green),
        ),
        title: Text(
          'Payment: -${formatMoney(entry.paidAmount, entry.currency)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateText),
            Text(
              'Remaining after: ${formatMoney(entry.remainingBalanceAfter, entry.currency)}',
            ),
            if (entry.note.isNotEmpty) Text(entry.note),
            if (entry.createdBy.isNotEmpty)
              Text(
                'By: ${entry.createdBy}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.shopping_bag_outlined),
      ),
      title: Text(
        'Debt added: ${formatMoney(entry.finalTotal, entry.currency)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateText),
          for (final product in entry.products)
            Text(
              '${product.name} ×${product.quantity} — '
              '${formatMoney(product.lineTotal, entry.currency)}',
            ),
          if (entry.manualAdjustment != 0)
            Text(
              'Subtotal ${formatMoney(entry.subtotal, entry.currency)}, '
              'Adjustment ${entry.manualAdjustment > 0 ? '+' : '-'}'
              '${formatMoney(entry.manualAdjustment.abs(), entry.currency)}',
            ),
          if (entry.paidAmount > 0)
            Text('Paid now: ${formatMoney(entry.paidAmount, entry.currency)}'),
          Text(
            'Remaining after: ${formatMoney(entry.remainingBalanceAfter, entry.currency)}',
          ),
          if (entry.note.isNotEmpty) Text(entry.note),
          if (entry.createdBy.isNotEmpty)
            Text(
              'By: ${entry.createdBy}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _DebtorTile extends StatelessWidget {
  const _DebtorTile({
    required this.debtor,
    required this.usdToLbpRate,
    required this.onPartialPayment,
    required this.onFullPayment,
    required this.onHistory,
    required this.onAddCharge,
    this.onDelete,
  });

  final Debtor debtor;
  final double usdToLbpRate;
  final void Function(Currency currency) onPartialPayment;
  final void Function(Currency currency) onFullPayment;
  final VoidCallback onHistory;
  /// Sends the user to the Products tab to pick items that get added
  /// straight to this debtor's balance (e.g. they're taking a new item on
  /// top of an existing charge).
  final VoidCallback onAddCharge;
  /// Only non-null for admins — deleting a debtor is a destructive,
  /// irreversible action (see [confirmDelete] usage at the call site).
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: debtor.isSettled ? Colors.green.withValues(alpha: 0.14) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: debtor.isSettled
            ? BorderSide(color: Colors.green.shade400, width: 1.4)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debtor.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        debtor.phoneNumber.isEmpty
                            ? 'No phone number'
                            : debtor.phoneNumber,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(debtor.isSettled ? 'Settled' : 'Pending'),
                  backgroundColor: debtor.isSettled
                      ? Colors.green.shade600
                      : null,
                  labelStyle: debtor.isSettled
                      ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)
                      : null,
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete debtor',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (debtor.hasUsdActivity)
              _CurrencyBalanceRow(
                currency: Currency.usd,
                debt: debtor.usdTotalDebt,
                paid: debtor.usdTotalPaid,
                remaining: debtor.usdRemainingAmount,
                usdToLbpRate: usdToLbpRate,
                onPartialPayment: () => onPartialPayment(Currency.usd),
                onFullPayment: debtor.usdRemainingAmount > 0
                    ? () => onFullPayment(Currency.usd)
                    : null,
              ),
            if (debtor.hasLbpActivity) ...[
              if (debtor.hasUsdActivity) const SizedBox(height: 10),
              _CurrencyBalanceRow(
                currency: Currency.lbp,
                debt: debtor.lbpTotalDebtAmount,
                paid: debtor.lbpTotalPaidAmount,
                remaining: debtor.lbpRemainingAmount,
                usdToLbpRate: usdToLbpRate,
                onPartialPayment: () => onPartialPayment(Currency.lbp),
                onFullPayment: debtor.lbpRemainingAmount > 0
                    ? () => onFullPayment(Currency.lbp)
                    : null,
              ),
            ],
            if (!debtor.hasUsdActivity && !debtor.hasLbpActivity)
              const Text('No debt recorded yet.'),
            if (debtor.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(debtor.note),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  debtor.dueDate == null
                      ? 'No due date'
                      : 'Due ${DateFormat.yMMMd().format(debtor.dueDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onAddCharge,
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Add charge'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onHistory,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('History'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyBalanceRow extends StatelessWidget {
  const _CurrencyBalanceRow({
    required this.currency,
    required this.debt,
    required this.paid,
    required this.remaining,
    required this.usdToLbpRate,
    required this.onPartialPayment,
    required this.onFullPayment,
  });

  final Currency currency;
  final double debt;
  final double paid;
  final double remaining;
  /// Only used to show the LBP equivalent under a USD row.
  final double usdToLbpRate;
  final VoidCallback onPartialPayment;
  final VoidCallback? onFullPayment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${currency == Currency.usd ? 'USD' : 'LBP'} Debt: '
            '${formatMoney(remaining, currency)} remaining',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'Total ${formatMoney(debt, currency)} • Paid ${formatMoney(paid, currency)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (currency == Currency.usd)
            Text(
              '≈ ${formatLbp(remaining, usdToLbpRate)} remaining',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPartialPayment,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Partial payment'),
              ),
              FilledButton.icon(
                onPressed: onFullPayment,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Full payment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add-debtor dialog covering both flows: selecting products from the
/// catalog (multi-item, with automatic pricing and stock/currency
/// enforcement) or a manually-entered amount, plus the same manual invoice
/// +/- adjustment used at checkout, an optional "amount paid now", and a
/// phone-contacts picker on mobile.
class _AddDebtorDialog extends StatefulWidget {
  const _AddDebtorDialog({required this.provider});

  final AppProvider provider;

  @override
  State<_AddDebtorDialog> createState() => _AddDebtorDialogState();
}

class _AddDebtorDialogState extends State<_AddDebtorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _manualAmountController = TextEditingController();
  final _paidNowController = TextEditingController();
  final _productSearchController = TextEditingController();
  final _adjustmentController = TextEditingController();

  DateTime _dueDate = DateTime.now();
  Currency _manualCurrency = Currency.usd;
  double _manualAdjustment = 0;
  List<CartItem> _selectedItems = [];
  bool _isSaving = false;

  bool get _usingProducts => _selectedItems.isNotEmpty;
  Currency get _effectiveCurrency =>
      _usingProducts ? _selectedItems.first.product.currency : _manualCurrency;
  double get _subtotal {
    if (_usingProducts) {
      return _selectedItems.fold(0.0, (sum, item) => sum + item.lineTotal);
    }
    return double.tryParse(_manualAmountController.text.trim()) ?? 0;
  }

  double get _finalTotal {
    final raw = _subtotal + _manualAdjustment;
    return raw < 0 ? 0 : raw;
  }

  double get _paidNow => double.tryParse(_paidNowController.text.trim()) ?? 0;
  double get _remaining => (_finalTotal - _paidNow).clamp(0, double.infinity);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _manualAmountController.dispose();
    _paidNowController.dispose();
    _productSearchController.dispose();
    _adjustmentController.dispose();
    super.dispose();
  }

  void _addProduct(Product product) {
    if (product.quantity <= 0) {
      _snack('${product.name} is out of stock.');
      return;
    }
    if (_selectedItems.isNotEmpty &&
        _selectedItems.first.product.currency != product.currency) {
      _snack(
        'Selected items are priced in ${_selectedItems.first.product.currency.name.toUpperCase()}. '
        'Remove them before adding a ${product.currency.name.toUpperCase()}-priced item.',
      );
      return;
    }
    final index = _selectedItems.indexWhere((i) => i.product.id == product.id);
    if (index == -1) {
      setState(
        () => _selectedItems = [
          ..._selectedItems,
          CartItem(product: product, quantity: 1),
        ],
      );
      return;
    }
    final existing = _selectedItems[index];
    if (existing.quantity >= product.quantity) {
      _snack('Only ${product.quantity} in stock for ${product.name}.');
      return;
    }
    final updated = List<CartItem>.from(_selectedItems);
    updated[index] = existing.copyWith(quantity: existing.quantity + 1);
    setState(() => _selectedItems = updated);
  }

  void _decrementProduct(String productId) {
    final index = _selectedItems.indexWhere((i) => i.product.id == productId);
    if (index == -1) return;
    final existing = _selectedItems[index];
    if (existing.quantity <= 1) {
      setState(
        () => _selectedItems = _selectedItems
            .where((i) => i.product.id != productId)
            .toList(),
      );
      return;
    }
    final updated = List<CartItem>.from(_selectedItems);
    updated[index] = existing.copyWith(quantity: existing.quantity - 1);
    setState(() => _selectedItems = updated);
  }

  void _incrementProduct(String productId) {
    final index = _selectedItems.indexWhere((i) => i.product.id == productId);
    if (index == -1) return;
    final existing = _selectedItems[index];
    if (existing.quantity >= existing.product.quantity) {
      _snack('Only ${existing.product.quantity} in stock for ${existing.product.name}.');
      return;
    }
    final updated = List<CartItem>.from(_selectedItems);
    updated[index] = existing.copyWith(quantity: existing.quantity + 1);
    setState(() => _selectedItems = updated);
  }

  void _removeProduct(String productId) {
    setState(
      () => _selectedItems =
          _selectedItems.where((i) => i.product.id != productId).toList(),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickContact() async {
    final contact = await pickPhoneContact();
    if (contact == null || !mounted) return;
    setState(() {
      if (contact.name.isNotEmpty) _nameController.text = contact.name;
      if (contact.phone.isNotEmpty) {
        _phoneController.text = formatLebanesePhoneDigits(contact.phone);
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_subtotal <= 0) {
      _snack('Select at least one product or enter a debt amount greater than zero.');
      return;
    }
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final effectiveDueDate = _dueDate;
    try {
      if (_usingProducts) {
        await widget.provider.checkoutCart(
          items: _selectedItems,
          customerName: _nameController.text.trim(),
          asDebt: true,
          customerPhone: _phoneController.text.trim(),
          debtDueDate: effectiveDueDate,
          debtNote: _noteController.text.trim(),
          manualAdjustment: _manualAdjustment,
          amountPaidNow: _paidNow,
        );
      } else {
        await widget.provider.addManualDebt(
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          amount: _subtotal,
          currency: _manualCurrency,
          note: _noteController.text.trim(),
          dueDate: effectiveDueDate,
          amountPaidNow: _paidNow,
          manualAdjustment: _manualAdjustment,
        );
      }
      navigator.pop('Debtor saved successfully.');
    } catch (error) {
      if (mounted) {
        _snack('Failed to save debtor: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _productSearchController.text.trim().isEmpty
        ? const <Product>[]
        : widget.provider
              .searchProducts(query: _productSearchController.text.trim())
              .take(6)
              .toList();

    return AlertDialog(
      title: const Text('Add debtor'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Customer name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Customer name is required.'
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [LebanesePhoneInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                        ),
                      ),
                    ),
                    if (supportsContactPicker) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _pickContact,
                        icon: const Icon(Icons.contacts_outlined),
                        label: const Text('Contacts'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  'Products (optional)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _productSearchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by name, barcode, serial, or category',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (matches.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final product = matches[index];
                        return ListTile(
                          dense: true,
                          title: Text(product.name),
                          subtitle: Text(
                            '${formatMoney(product.sellingPrice, product.currency)} • '
                            'Stock ${product.quantity}',
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _addProduct(product),
                        );
                      },
                    ),
                  ),
                if (_selectedItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._selectedItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.product.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _decrementProduct(item.product.id),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _incrementProduct(item.product.id),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              formatMoney(item.lineTotal, item.product.currency),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _removeProduct(item.product.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!_usingProducts) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _manualAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Debt amount (no specific products)',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<Currency>(
                        segments: const [
                          ButtonSegment(value: Currency.usd, label: Text('USD')),
                          ButtonSegment(value: Currency.lbp, label: Text('LBP')),
                        ],
                        selected: {_manualCurrency},
                        onSelectionChanged: (selection) =>
                            setState(() => _manualCurrency = selection.first),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                Text(
                  'Manual adjustment',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _adjustmentController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Adjustment (+/-) in ${_effectiveCurrency.symbol}',
                    hintText: 'e.g. -5 or 10',
                    suffixIcon: _manualAdjustment != 0
                        ? IconButton(
                            tooltip: 'Clear adjustment',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _adjustmentController.clear();
                              _manualAdjustment = 0;
                            }),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {
                    _manualAdjustment = double.tryParse(value.trim()) ?? 0;
                  }),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _paidNowController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount paid now (optional)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _dueDate,
                      );
                      if (selected != null) {
                        setState(() => _dueDate = selected);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      'Due date: ${DateFormat.yMMMd().format(_dueDate)}',
                    ),
                  ),
                ),
                const Divider(),
                _totalsSummary(context),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _totalsSummary(BuildContext context) {
    final currency = _effectiveCurrency;
    final rate = widget.provider.usdToLbpRate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Subtotal', formatMoney(_subtotal, currency)),
        if (_manualAdjustment != 0)
          _summaryRow(
            'Manual Adjustment',
            '${_manualAdjustment > 0 ? '+' : '-'}${formatMoney(_manualAdjustment.abs(), currency)}',
          ),
        _summaryRow(
          'Final Total',
          formatMoney(_finalTotal, currency),
          bold: true,
          secondaryValue: currency == Currency.usd
              ? formatLbp(_finalTotal, rate)
              : null,
        ),
        if (_paidNow > 0) _summaryRow('Paid now', formatMoney(_paidNow, currency)),
        _summaryRow(
          'Remaining debt',
          formatMoney(_remaining, currency),
          secondaryValue: currency == Currency.usd
              ? formatLbp(_remaining, rate)
              : null,
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    String? secondaryValue,
  }) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: style),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: style),
              if (secondaryValue != null)
                Text(
                  secondaryValue,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
