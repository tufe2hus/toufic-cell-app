import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/business_record_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/currency_format.dart';
import '../../utils/export_utils.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/price_text.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _paymentMethod = 'All';
  String _employee = 'All';
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');
    final showProfits = provider.canViewProfits;
    final visibleTransactions = provider.isAdmin
        ? provider.transactions
        : provider.currentUserTransactions;
    final employees = <String>{
      'All',
      // Every registered employee, not just ones who already have a
      // transaction on record — so a newly added employee shows up in the
      // filter right away instead of only after their first sale.
      ...provider.users.map((user) => user.email).where((email) => email.isNotEmpty),
      ...visibleTransactions
          .map((item) => item.createdBy)
          .where((item) => item.isNotEmpty),
    };
    final paymentMethods = <String>{
      'All',
      ...visibleTransactions.map((item) => item.paymentMethod),
    };
    final query = _searchController.text.trim().toLowerCase();
    final filtered = visibleTransactions.where((transaction) {
      final matchesQuery =
          query.isEmpty ||
          transaction.invoiceNumber.toLowerCase().contains(query) ||
          transaction.customerName.toLowerCase().contains(query) ||
          transaction.createdBy.toLowerCase().contains(query);
      final matchesPayment =
          _paymentMethod == 'All' ||
          transaction.paymentMethod == _paymentMethod;
      final matchesEmployee =
          _employee == 'All' || transaction.createdBy == _employee;
      final matchesDate =
          _dateRange == null ||
          (!transaction.createdAt.isBefore(_dateRange!.start) &&
              !transaction.createdAt.isAfter(
                _dateRange!.end.add(const Duration(days: 1)),
              ));
      return matchesQuery && matchesPayment && matchesEmployee && matchesDate;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search invoice, customer, employee',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Payment'),
                  items: paymentMethods
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _paymentMethod = value ?? 'All'),
                ),
              ),
              if (provider.isAdmin)
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _employee,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Employee'),
                    items: employees
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              item,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _employee = value ?? 'All'),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _dateRange,
                  );
                  if (range != null) {
                    setState(() => _dateRange = range);
                  }
                },
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _dateRange == null
                      ? 'Filter date'
                      : DateFormat.yMMMd().format(_dateRange!.start),
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
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Text(
                        'Transactions overview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      );
                      final exportButtons = FilledButton.tonalIcon(
                        onPressed: filtered.isEmpty
                            ? null
                            : () => _exportExcel(context, filtered, showProfits),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Excel'),
                      );
                      if (constraints.maxWidth >= 480) {
                        return Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 16),
                            Flexible(child: exportButtons),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 10),
                          exportButtons,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No transactions match the selected filters.',
                      ),
                    )
                  else
                    ...filtered.map(
                      (transaction) => _TransactionTile(
                        transaction: transaction,
                        currency: currency,
                        showProfit: showProfits,
                        onViewDetails: () =>
                            _showDetails(context, transaction, currency),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportExcel(
    BuildContext context,
    List<TransactionRecord> transactions,
    bool showProfit,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await exportTransactionsExcel(
        transactions: transactions,
        showProfit: showProfit,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Excel export failed: $error')),
      );
    }
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    TransactionRecord transaction,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this transaction?',
      message:
          'This permanently deletes invoice ${transaction.invoiceNumber}, removes its sale records, and restores the stock it sold. This cannot be undone.',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await Provider.of<AppProvider>(
        context,
        listen: false,
      ).deleteTransaction(transaction);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted invoice ${transaction.invoiceNumber}.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete transaction: $error')),
        );
      }
    }
  }

  void _showDetails(
    BuildContext context,
    TransactionRecord transaction,
    NumberFormat currency,
  ) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final showProfits = provider.canViewProfits;
    final rate = provider.usdToLbpRate;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invoice ${transaction.invoiceNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${transaction.customerName}'),
              Text('Payment: ${transaction.paymentMethod}'),
              Text('Products: ${transaction.productCount}'),
              Text(
                'Total: ${currency.format(transaction.totalAmount)} (${formatLbp(transaction.totalAmount, rate)})',
              ),
              if (showProfits)
                Text(
                  'Profit: ${currency.format(transaction.profit)} (${formatLbp(transaction.profit, rate)})',
                ),
              Text(
                'Created by: ${transaction.createdBy.isEmpty ? 'Unknown' : transaction.createdBy}',
              ),
              if (transaction.productNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Items: ${transaction.productNames.join(', ')}'),
              ],
            ],
          ),
          actions: [
            if (provider.isAdmin)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteTransaction(this.context, transaction);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.tonal(
              onPressed: () {
                Navigator.of(context).pop();
                _showExportMessage(
                  context,
                  'Print action prepared for ${transaction.invoiceNumber}',
                );
              },
              child: const Text('Print invoice'),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.currency,
    required this.showProfit,
    required this.onViewDetails,
  });

  final TransactionRecord transaction;
  final NumberFormat currency;
  final bool showProfit;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<AppProvider>().usdToLbpRate;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            transaction.customerName.isEmpty
                ? '?'
                : transaction.customerName[0].toUpperCase(),
          ),
        ),
        title: Text(
          '${transaction.invoiceNumber} • ${transaction.customerName}',
        ),
        subtitle: Text(
          '${DateFormat.yMMMd().format(transaction.createdAt)} ${DateFormat.Hm().format(transaction.createdAt)} • ${transaction.paymentMethod} • ${transaction.productCount} item(s)',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PriceText(
              transaction.totalAmount,
              currency: transaction.currency,
              crossAxisAlignment: CrossAxisAlignment.end,
            ),
            Text(
              showProfit
                  ? 'Profit ${currency.format(transaction.profit)} (${formatLbp(transaction.profit, rate)})'
                  : transaction.paymentMethod,
            ),
          ],
        ),
        onTap: onViewDetails,
      ),
    );
  }
}
