import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/business_record_models.dart';
import '../../models/currency.dart';
import '../../models/product_model.dart';
import '../../providers/app_provider.dart';
import '../../utils/contacts_picker.dart';
import '../../utils/currency_format.dart';
import '../../utils/phone_normalization.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/metric_card.dart';

/// People or suppliers the store owes money to — the reverse of the
/// Debtors screen. Shares the exact same [Debtor] record shape and payment
/// machinery (see [AppProvider.creditors]/[AppProvider.recordPayment]); the
/// only difference is direction (`theyOweMe: false`) and that entries here
/// are always a manual amount, never tied to products the store sold.
class CreditorsManagementScreen extends StatefulWidget {
  const CreditorsManagementScreen({super.key});

  @override
  State<CreditorsManagementScreen> createState() =>
      _CreditorsManagementScreenState();
}

class _CreditorsManagementScreenState
    extends State<CreditorsManagementScreen> {
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
    if (!provider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('People I owe')),
        body: const Center(
          child: Text('Only admins can access the people-I-owe ledger.'),
        ),
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    final filtered = provider.creditors.where((creditor) {
      final matchesQuery =
          query.isEmpty ||
          creditor.name.toLowerCase().contains(query) ||
          creditor.phoneNumber.toLowerCase().contains(query);
      final matchesCurrency = switch (_currencyFilter) {
        null => true,
        Currency.usd => creditor.hasUsdActivity,
        Currency.lbp => creditor.hasLbpActivity,
      };
      return matchesQuery && matchesCurrency;
    }).toList();
    final activeCreditors = filtered
        .where((creditor) => !creditor.isSettled)
        .toList();
    final paidCreditors = filtered
        .where((creditor) => creditor.isSettled)
        .toList();

    final totalUsdOwed = provider.creditors.fold<double>(
      0,
      (sum, creditor) => sum + creditor.usdRemainingAmount,
    );
    final totalLbpOwed = provider.creditors.fold<double>(
      0,
      (sum, creditor) => sum + creditor.lbpRemainingAmount,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('People I owe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.currentUser != null
            ? () => _showAddCreditorDialog(context, provider)
            : null,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add person'),
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
                  title: 'People I owe',
                  value: provider.pendingCreditors.toString(),
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
                    title: 'Remaining USD owed',
                    value: formatMoney(totalUsdOwed, Currency.usd),
                    secondaryValue: formatLbp(totalUsdOwed, provider.usdToLbpRate),
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
                    title: 'Remaining LBP owed',
                    value: formatMoney(totalLbpOwed, Currency.lbp),
                    subtitle: 'Tap to filter',
                    icon: Icons.account_balance_wallet_outlined,
                    colors: const [Color(0xFFA855F7), Color(0xFF7E22CE)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search person or phone number',
            ),
          ),
          if (_currencyFilter != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(
                  'Showing ${_currencyFilter == Currency.usd ? 'USD' : 'LBP'}-owed people only',
                ),
                onDeleted: () => setState(() => _currencyFilter = null),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (activeCreditors.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No one you currently owe money to.'),
              ),
            )
          else
            ...activeCreditors.map(
              (creditor) => _CreditorTile(
                creditor: creditor,
                usdToLbpRate: provider.usdToLbpRate,
                onPartialPay: (currency) =>
                    _showPayDialog(context, provider, creditor, currency),
                onFullPay: (currency) =>
                    _payInFull(context, provider, creditor, currency),
                onHistory: () => _showHistoryDialog(context, provider, creditor),
                onDelete: provider.isAdmin
                    ? () => _deleteCreditor(context, provider, creditor)
                    : null,
              ),
            ),
          if (paidCreditors.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Paid/Completed',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...paidCreditors.map(
              (creditor) => _CreditorTile(
                creditor: creditor,
                usdToLbpRate: provider.usdToLbpRate,
                onPartialPay: (currency) =>
                    _showPayDialog(context, provider, creditor, currency),
                onFullPay: (currency) =>
                    _payInFull(context, provider, creditor, currency),
                onHistory: () => _showHistoryDialog(context, provider, creditor),
                onDelete: provider.isAdmin
                    ? () => _deleteCreditor(context, provider, creditor)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAddCreditorDialog(
    BuildContext context,
    AppProvider provider,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AddCreditorDialog(provider: provider),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _showPayDialog(
    BuildContext context,
    AppProvider provider,
    Debtor creditor,
    Currency currency,
  ) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSubmitting = false;
    final remaining = currency == Currency.usd
        ? creditor.usdRemainingAmount
        : creditor.lbpRemainingAmount;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Pay ${creditor.name} (${currency.symbol})'),
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
                      labelText: 'Amount paid (${currency.symbol})',
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
                                  'Payment cannot exceed remaining balance '
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
                            debtorId: creditor.id,
                            customerName: creditor.name,
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
                              creditor,
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

  Future<void> _payInFull(
    BuildContext context,
    AppProvider provider,
    Debtor creditor,
    Currency currency,
  ) async {
    final remaining = currency == Currency.usd
        ? creditor.usdRemainingAmount
        : creditor.lbpRemainingAmount;
    if (remaining <= 0) {
      return;
    }
    final payment = PaymentRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      debtorId: creditor.id,
      customerName: creditor.name,
      amount: remaining,
      note: 'Paid in full',
      receivedBy: provider.currentUser?.email ?? 'Unknown',
      paidAt: DateTime.now(),
      currency: currency,
    );
    try {
      await provider.recordPayment(payment, creditor, currency: currency);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${creditor.name} is fully paid in ${currency.symbol}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $error')),
        );
      }
    }
  }

  Future<void> _deleteCreditor(
    BuildContext context,
    AppProvider provider,
    Debtor creditor,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete ${creditor.name}?',
      message:
          'This permanently deletes this person and their full payment '
          'history from the database. No balance calculation is performed. '
          'This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteDebtor(creditor);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${creditor.name}.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $error')),
        );
      }
    }
  }

  void _showHistoryDialog(
    BuildContext context,
    AppProvider provider,
    Debtor creditor,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('History – ${creditor.name}'),
          content: SizedBox(
            width: 480,
            child: StreamBuilder<List<DebtorTransaction>>(
              stream: provider.debtorTransactionsStream(creditor.id),
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
          'Paid: -${formatMoney(entry.paidAmount, entry.currency)}',
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
        child: const Icon(Icons.request_quote_outlined),
      ),
      title: Text(
        'Amount owed: ${formatMoney(entry.finalTotal, entry.currency)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateText),
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

class _CreditorTile extends StatelessWidget {
  const _CreditorTile({
    required this.creditor,
    required this.usdToLbpRate,
    required this.onPartialPay,
    required this.onFullPay,
    required this.onHistory,
    this.onDelete,
  });

  final Debtor creditor;
  final double usdToLbpRate;
  final void Function(Currency currency) onPartialPay;
  final void Function(Currency currency) onFullPay;
  final VoidCallback onHistory;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: creditor.isSettled ? Colors.green.withValues(alpha: 0.14) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: creditor.isSettled
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
                        creditor.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        creditor.phoneNumber.isEmpty
                            ? 'No phone number'
                            : creditor.phoneNumber,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(creditor.isSettled ? 'Settled' : 'Owed'),
                  backgroundColor: creditor.isSettled
                      ? Colors.green.shade600
                      : null,
                  labelStyle: creditor.isSettled
                      ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)
                      : null,
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (creditor.hasUsdActivity)
              _CurrencyOwedRow(
                currency: Currency.usd,
                owed: creditor.usdTotalDebt,
                paid: creditor.usdTotalPaid,
                remaining: creditor.usdRemainingAmount,
                usdToLbpRate: usdToLbpRate,
                onPartialPay: () => onPartialPay(Currency.usd),
                onFullPay: creditor.usdRemainingAmount > 0
                    ? () => onFullPay(Currency.usd)
                    : null,
              ),
            if (creditor.hasLbpActivity) ...[
              if (creditor.hasUsdActivity) const SizedBox(height: 10),
              _CurrencyOwedRow(
                currency: Currency.lbp,
                owed: creditor.lbpTotalDebtAmount,
                paid: creditor.lbpTotalPaidAmount,
                remaining: creditor.lbpRemainingAmount,
                usdToLbpRate: usdToLbpRate,
                onPartialPay: () => onPartialPay(Currency.lbp),
                onFullPay: creditor.lbpRemainingAmount > 0
                    ? () => onFullPay(Currency.lbp)
                    : null,
              ),
            ],
            if (!creditor.hasUsdActivity && !creditor.hasLbpActivity)
              const Text('No balance recorded yet.'),
            if (creditor.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(creditor.note),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  creditor.dueDate == null
                      ? 'No due date'
                      : 'Due ${DateFormat.yMMMd().format(creditor.dueDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyOwedRow extends StatelessWidget {
  const _CurrencyOwedRow({
    required this.currency,
    required this.owed,
    required this.paid,
    required this.remaining,
    required this.usdToLbpRate,
    required this.onPartialPay,
    required this.onFullPay,
  });

  final Currency currency;
  final double owed;
  final double paid;
  final double remaining;
  final double usdToLbpRate;
  final VoidCallback onPartialPay;
  final VoidCallback? onFullPay;

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
            '${currency == Currency.usd ? 'USD' : 'LBP'} owed: '
            '${formatMoney(remaining, currency)} remaining',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'Total ${formatMoney(owed, currency)} • Paid ${formatMoney(paid, currency)}',
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
                onPressed: onPartialPay,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Pay some'),
              ),
              FilledButton.icon(
                onPressed: onFullPay,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Pay in full'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add-creditor dialog — a manually-entered amount only (people/suppliers
/// the store owes aren't taking products from the store, unlike a debtor,
/// so there's no product picker here), plus an optional "amount paid now"
/// and a phone-contacts picker on mobile.
class _AddCreditorDialog extends StatefulWidget {
  const _AddCreditorDialog({required this.provider});

  final AppProvider provider;

  @override
  State<_AddCreditorDialog> createState() => _AddCreditorDialogState();
}

class _AddCreditorDialogState extends State<_AddCreditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountController = TextEditingController();
  final _paidNowController = TextEditingController();

  DateTime _dueDate = DateTime.now();
  Currency _currency = Currency.usd;
  bool _isSaving = false;

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;
  double get _paidNow => double.tryParse(_paidNowController.text.trim()) ?? 0;
  double get _remaining => (_amount - _paidNow).clamp(0, double.infinity);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    _amountController.dispose();
    _paidNowController.dispose();
    super.dispose();
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
    if (_amount <= 0) {
      _snack('Enter an amount greater than zero.');
      return;
    }
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final effectiveDueDate = _dueDate;
    try {
      await widget.provider.addManualDebt(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        amount: _amount,
        currency: _currency,
        note: _noteController.text.trim(),
        dueDate: effectiveDueDate,
        amountPaidNow: _paidNow,
        theyOweMe: false,
      );
      navigator.pop('Person added successfully.');
    } catch (error) {
      if (mounted) {
        _snack('Failed to save: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add person I owe'),
      content: SizedBox(
        width: 420,
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
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Name is required.'
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount I owe',
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
                      selected: {_currency},
                      onSelectionChanged: (selection) =>
                          setState(() => _currency = selection.first),
                    ),
                  ],
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
                _summaryRow('Amount', formatMoney(_amount, _currency)),
                if (_paidNow > 0)
                  _summaryRow('Paid now', formatMoney(_paidNow, _currency)),
                _summaryRow(
                  'Remaining',
                  formatMoney(_remaining, _currency),
                  bold: true,
                  secondaryValue: _currency == Currency.usd
                      ? formatLbp(_remaining, widget.provider.usdToLbpRate)
                      : null,
                ),
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
