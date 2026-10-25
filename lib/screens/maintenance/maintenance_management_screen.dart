import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/currency.dart';
import '../../models/maintenance_job_model.dart';
import '../../providers/app_provider.dart';
import '../../utils/contacts_picker.dart';
import '../../utils/phone_normalization.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/role_guard.dart';

class MaintenanceManagementScreen extends StatelessWidget {
  const MaintenanceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(
      allowAdmin: true,
      child: _MaintenanceManagementView(),
    );
  }
}

class _MaintenanceManagementView extends StatefulWidget {
  const _MaintenanceManagementView();

  @override
  State<_MaintenanceManagementView> createState() =>
      _MaintenanceManagementViewState();
}

class _MaintenanceManagementViewState
    extends State<_MaintenanceManagementView> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final jobs = provider.maintenanceJobs;
    final now = DateTime.now();
    final thisMonth = jobs.where(
      (job) => job.date.year == now.year && job.date.month == now.month,
    );
    final totalProfitThisMonth = thisMonth.fold<double>(
      0,
      (sum, job) => sum + job.profit,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance / Repair jobs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddJobDialog(context, provider),
        icon: const Icon(Icons.build_circle_outlined),
        label: const Text('Log a job'),
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
                  title: 'Jobs logged',
                  value: jobs.length.toString(),
                  icon: Icons.build_circle_outlined,
                  colors: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                ),
              ),
              SizedBox(
                width: 250,
                child: MetricCard(
                  title: 'Profit this month',
                  value: formatMoney(totalProfitThisMonth, Currency.usd),
                  icon: Icons.trending_up_rounded,
                  colors: const [Color(0xFF22C55E), Color(0xFF15803D)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (jobs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No maintenance jobs logged yet.'),
              ),
            )
          else
            ...jobs.map(
              (job) => _JobTile(
                job: job,
                onDelete: () => _confirmDeleteJob(context, provider, job),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddJobDialog(
    BuildContext context,
    AppProvider provider,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AddJobDialog(provider: provider),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _confirmDeleteJob(
    BuildContext context,
    AppProvider provider,
    MaintenanceJob job,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this job?',
      message:
          'This permanently deletes the maintenance job for '
          '"${job.deviceDescription}". This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteMaintenanceJob(job);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete job: $error')),
        );
      }
    }
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.onDelete});

  final MaintenanceJob job;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.deviceDescription,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(DateFormat('dd/MM/yyyy').format(job.date)),
                    ],
                  ),
                ),
                Text(
                  formatMoney(job.profit, job.currency),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: job.profit >= 0
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete job',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(job.workDescription),
            const SizedBox(height: 8),
            Text(
              'Cost ${formatMoney(job.purchasePrice, job.currency)} • '
              'Charged ${formatMoney(job.sellingPrice, job.currency)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${job.customerName.isEmpty ? 'Walk-in customer' : job.customerName}'
              '${job.customerPhone.isEmpty ? '' : ' • ${job.customerPhone}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (job.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(job.note, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (job.createdBy.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Logged by: ${job.createdBy}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddJobDialog extends StatefulWidget {
  const _AddJobDialog({required this.provider});

  final AppProvider provider;

  @override
  State<_AddJobDialog> createState() => _AddJobDialogState();
}

class _AddJobDialogState extends State<_AddJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _deviceController = TextEditingController();
  final _workController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _sellingController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deviceController.dispose();
    _workController.dispose();
    _purchaseController.dispose();
    _sellingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    final contact = await pickPhoneContact();
    if (contact == null || !mounted) return;
    setState(() {
      if (contact.name.isNotEmpty) {
        _customerNameController.text = contact.name;
      }
      if (contact.phone.isNotEmpty) {
        _customerPhoneController.text = formatLebanesePhoneDigits(contact.phone);
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.provider.createMaintenanceJob(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        deviceDescription: _deviceController.text.trim(),
        workDescription: _workController.text.trim(),
        purchasePrice: double.tryParse(_purchaseController.text.trim()) ?? 0,
        sellingPrice: double.tryParse(_sellingController.text.trim()) ?? 0,
        note: _noteController.text.trim(),
        date: _date,
      );
      navigator.pop('Maintenance job logged successfully.');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to log job: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log a maintenance job'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _deviceController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Device (e.g. iPhone 12, Samsung A32)',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Device description is required.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _workController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What was done to the phone',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe the work done.'
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _purchaseController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cost (parts, etc)',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').trim(),
                          );
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid cost.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Charged to customer',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').trim(),
                          );
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid amount.';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer name (optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerPhoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [LebanesePhoneInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Customer phone (optional)',
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
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDate: _date,
                      );
                      if (selected != null) {
                        setState(() => _date = selected);
                      }
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(DateFormat.yMMMd().format(_date)),
                  ),
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
}
