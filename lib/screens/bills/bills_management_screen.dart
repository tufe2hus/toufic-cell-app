import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/bill_model.dart';
import '../../providers/app_provider.dart';
import '../../utils/currency_format.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/price_text.dart';
import '../../widgets/role_guard.dart';

class BillsManagementScreen extends StatelessWidget {
  const BillsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(allowAdmin: true, child: _BillsManagementView());
  }
}

class _BillsManagementView extends StatefulWidget {
  const _BillsManagementView();

  @override
  State<_BillsManagementView> createState() => _BillsManagementViewState();
}

class _BillsManagementViewState extends State<_BillsManagementView> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency = NumberFormat.currency(symbol: r'$');
    final now = DateTime.now();
    final bills = provider.bills;
    final today = bills.where(
      (bill) =>
          bill.paidAt.year == now.year &&
          bill.paidAt.month == now.month &&
          bill.paidAt.day == now.day,
    );
    final thisMonth = bills.where(
      (bill) => bill.paidAt.year == now.year && bill.paidAt.month == now.month,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogBillDialog(context, provider),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Log a bill'),
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
                  title: 'Paid today',
                  value: currency.format(
                    today.fold<double>(0, (sum, bill) => sum + bill.amount),
                  ),
                  secondaryValue: formatLbp(
                    today.fold<double>(0, (sum, bill) => sum + bill.amount),
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.today_outlined,
                  colors: const [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
              ),
              SizedBox(
                width: 250,
                child: MetricCard(
                  title: 'Paid this month',
                  value: currency.format(
                    thisMonth.fold<double>(0, (sum, bill) => sum + bill.amount),
                  ),
                  secondaryValue: formatLbp(
                    thisMonth.fold<double>(0, (sum, bill) => sum + bill.amount),
                    provider.usdToLbpRate,
                  ),
                  icon: Icons.calendar_month_outlined,
                  colors: const [Color(0xFFA855F7), Color(0xFF7E22CE)],
                ),
              ),
              SizedBox(
                width: 250,
                child: MetricCard(
                  title: 'Bills logged',
                  value: bills.length.toString(),
                  icon: Icons.receipt_long_outlined,
                  colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (bills.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No bills logged yet.'),
              ),
            )
          else
            ...bills.map(
              (bill) => _BillTile(
                bill: bill,
                currency: currency,
                onDelete: () => _confirmDeleteBill(context, provider, bill),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showLogBillDialog(
    BuildContext context,
    AppProvider provider,
  ) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime paidAt = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log a bill'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Bill name (e.g. Rent, Electricity)',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Bill name is required.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount paid',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount greater than zero.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: noteController,
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
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now(),
                              initialDate: paidAt,
                            );
                            if (selected != null) {
                              setDialogState(() => paidAt = selected);
                            }
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            'Paid on ${DateFormat.yMMMd().format(paidAt)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() => _isSubmitting = true);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await provider.createBill(
                              name: nameController.text.trim(),
                              amount: double.parse(
                                amountController.text.trim(),
                              ),
                              note: noteController.text.trim(),
                              paidAt: paidAt,
                            );
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Bill logged successfully.'),
                              ),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to log bill: $error'),
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => _isSubmitting = false);
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _confirmDeleteBill(
    BuildContext context,
    AppProvider provider,
    Bill bill,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete bill?',
      message:
          'This removes "${bill.name}" from your bills log and adds its amount back into profit for the period it was paid in.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteBill(bill);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete bill: $error')),
        );
      }
    }
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({
    required this.bill,
    required this.currency,
    required this.onDelete,
  });

  final Bill bill;
  final NumberFormat currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd/MM/yyyy').format(bill.paidAt)),
                  if (bill.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(bill.note),
                  ],
                  if (bill.paidBy.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Logged by: ${bill.paidBy}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PriceText(
                  bill.amount,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete bill',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
