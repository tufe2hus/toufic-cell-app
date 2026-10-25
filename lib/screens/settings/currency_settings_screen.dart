import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../utils/currency_format.dart';
import '../../widgets/role_guard.dart';

class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(
      allowAdmin: true,
      child: _CurrencySettingsView(),
    );
  }
}

class _CurrencySettingsView extends StatefulWidget {
  const _CurrencySettingsView();

  @override
  State<_CurrencySettingsView> createState() => _CurrencySettingsViewState();
}

class _CurrencySettingsViewState extends State<_CurrencySettingsView> {
  late final TextEditingController _rateController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save(AppProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.updateUsdToLbpRate(
        double.parse(_rateController.text.trim()),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Exchange rate updated.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update rate: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!_initialized) {
      _rateController = TextEditingController(
        text: provider.usdToLbpRate == provider.usdToLbpRate.roundToDouble()
            ? provider.usdToLbpRate.toStringAsFixed(0)
            : provider.usdToLbpRate.toString(),
      );
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Currency')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'USD → LBP exchange rate',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This rate is used to show the Lebanese Lira equivalent '
                    'next to every dollar amount in the app — products, cart, '
                    'transactions, debtors, reports, and bills.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1 USD = ',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              suffixText: 'LBP',
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                (value ?? '').trim(),
                              );
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a valid rate greater than zero.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current rate: 1 USD = ${NumberFormat.decimalPattern('en_US').format(provider.usdToLbpRate)} LBP',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Example: ${NumberFormat.currency(symbol: r'$').format(10)} ≈ ${formatLbp(10, provider.usdToLbpRate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _isSaving ? null : () => _save(provider),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save rate'),
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
}
