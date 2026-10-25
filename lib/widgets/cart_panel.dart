import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../models/currency.dart';
import '../providers/app_provider.dart';
import '../providers/cart_provider.dart';
import '../utils/contacts_picker.dart';
import '../utils/phone_normalization.dart';
import 'price_text.dart';

class CartPanel extends StatefulWidget {
  const CartPanel({super.key});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  bool _isCheckingOut = false;
  // Reused across a retry of the *same* cart so a slow-network failure that
  // actually committed server-side can't be double-submitted; regenerated
  // whenever the cart's contents actually change (see [_cartFingerprint]).
  String? _pendingSaleKey;
  Object? _pendingSaleFingerprint;
  String? _pendingDebtKey;
  Object? _pendingDebtFingerprint;

  Object _cartFingerprint(CartProvider cart) => Object.hashAll([
    for (final item in cart.items) Object.hash(item.product.id, item.quantity),
    cart.manualAdjustment,
  ]);

  Future<void> _completeSale(BuildContext context, CartProvider cart) async {
    if (_isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    final fingerprint = _cartFingerprint(cart);
    if (_pendingSaleKey == null || _pendingSaleFingerprint != fingerprint) {
      _pendingSaleKey = 'sale-${DateTime.now().microsecondsSinceEpoch}';
      _pendingSaleFingerprint = fingerprint;
    }
    try {
      final appProvider = context.read<AppProvider>();
      final result = await appProvider.checkoutCart(
        items: cart.items,
        manualAdjustment: cart.manualAdjustment,
        idempotencyKey: _pendingSaleKey,
      );
      _pendingSaleKey = null;
      _pendingSaleFingerprint = null;
      cart.clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sale complete — Invoice ${result.invoiceNumber} '
            '(${formatMoney(result.totalAmount, result.currency)})',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error is CheckoutException
          ? error.message
          : 'Checkout failed: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  /// Completes checkout straight to [target]'s balance — used when the cart
  /// was opened via the Debtors screen's "Add charge" button, so the
  /// customer name/phone are already known and shouldn't be re-asked.
  Future<void> _addChargeToTarget(
    BuildContext context,
    CartProvider cart,
    DebtorChargeTarget target,
  ) async {
    if (_isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    final fingerprint = _cartFingerprint(cart);
    if (_pendingDebtKey == null || _pendingDebtFingerprint != fingerprint) {
      _pendingDebtKey = 'debt-${DateTime.now().microsecondsSinceEpoch}';
      _pendingDebtFingerprint = fingerprint;
    }
    try {
      final appProvider = context.read<AppProvider>();
      final result = await appProvider.checkoutCart(
        items: cart.items,
        customerName: target.name,
        asDebt: true,
        customerPhone: target.phone,
        manualAdjustment: cart.manualAdjustment,
        idempotencyKey: _pendingDebtKey,
        existingDebtorId: target.id,
      );
      _pendingDebtKey = null;
      _pendingDebtFingerprint = null;
      cart.clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to ${target.name}\'s debt — Invoice ${result.invoiceNumber} '
            '(${formatMoney(result.totalAmount, result.currency)})',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error is CheckoutException
          ? error.message
          : 'Checkout failed: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  Future<void> _addAsDebtor(BuildContext context, CartProvider cart) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime dueDate = DateTime.now();

    Future<void> pickContact(void Function(void Function()) setDialogState) async {
      final contact = await pickPhoneContact();
      if (contact == null) return;
      if (contact.name.isNotEmpty) nameController.text = contact.name;
      if (contact.phone.isNotEmpty) {
        phoneController.text = formatLebanesePhoneDigits(contact.phone);
      }
      setDialogState(() {});
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add as debtor'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                      ),
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
                            controller: phoneController,
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
                            onPressed: () => pickContact(setDialogState),
                            icon: const Icon(Icons.contacts_outlined),
                            label: const Text('Contacts'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: dialogContext,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDate: dueDate,
                          );
                          if (selected != null) {
                            setDialogState(() => dueDate = selected);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          'Due date: ${DateFormat.yMMMd().format(dueDate)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Add as debtor'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    if (_isCheckingOut) return;
    setState(() => _isCheckingOut = true);
    final fingerprint = _cartFingerprint(cart);
    if (_pendingDebtKey == null || _pendingDebtFingerprint != fingerprint) {
      _pendingDebtKey = 'debt-${DateTime.now().microsecondsSinceEpoch}';
      _pendingDebtFingerprint = fingerprint;
    }
    try {
      final appProvider = context.read<AppProvider>();
      final customerName = nameController.text.trim();
      final result = await appProvider.checkoutCart(
        items: cart.items,
        customerName: customerName,
        asDebt: true,
        customerPhone: phoneController.text.trim(),
        debtDueDate: dueDate,
        manualAdjustment: cart.manualAdjustment,
        idempotencyKey: _pendingDebtKey,
      );
      _pendingDebtKey = null;
      _pendingDebtFingerprint = null;
      cart.clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added as debt for $customerName — Invoice ${result.invoiceNumber} '
            '(${formatMoney(result.totalAmount, result.currency)})',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = error is CheckoutException
          ? error.message
          : 'Checkout failed: $error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isCheckingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final chargeTarget = cart.chargeTarget;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Current Sale',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                if (!cart.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${cart.lineItemCount}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            if (chargeTarget != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Charging to ${chargeTarget.name}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Cancel charge',
                      onPressed: _isCheckingOut ? null : cart.clearChargeTarget,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (cart.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.point_of_sale_outlined,
                      size: 36,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap a product to add it to the sale.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cart.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) =>
                      _CartRow(item: cart.items[index], cart: cart),
                ),
              ),
            const Divider(height: 24),
            if (!cart.isEmpty) ...[
              _ManualAdjustmentRow(cart: cart),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cart.manualAdjustment == 0 ? 'Total' : 'Final Total',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                PriceText(
                  cart.finalTotal,
                  currency: cart.currency ?? Currency.usd,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (chargeTarget != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: cart.isEmpty || _isCheckingOut
                      ? null
                      : () => _addChargeToTarget(context, cart, chargeTarget),
                  icon: _isCheckingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart_outlined),
                  label: Text('Add to ${chargeTarget.name}\'s debt'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: cart.isEmpty || _isCheckingOut
                      ? null
                      : () => _completeSale(context, cart),
                  child: _isCheckingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Complete Sale'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: cart.isEmpty || _isCheckingOut
                      ? null
                      : () => _addAsDebtor(context, cart),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add as Debtor'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Manual +/- invoice adjustment (see requirement: quick +/-$1/+/-$5
/// buttons). Purely changes the amount charged on this invoice — never
/// touches product price, quantity, or stock.
class _ManualAdjustmentRow extends StatelessWidget {
  const _ManualAdjustmentRow({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final currency = cart.currency ?? Currency.usd;
    final small = CurrencySteps.small(currency);
    final large = CurrencySteps.large(currency);
    final adjustment = cart.manualAdjustment;

    Widget adjustButton(String label, double delta) {
      return OutlinedButton(
        onPressed: () => cart.adjustManual(delta),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subtotal', style: Theme.of(context).textTheme.bodyMedium),
            Text(formatMoney(cart.subtotal, currency)),
          ],
        ),
        if (adjustment != 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Manual Adjustment',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${adjustment > 0 ? '+' : '-'}${formatMoney(adjustment.abs(), currency)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: adjustment > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            adjustButton('-${formatMoney(large, currency)}', -large),
            adjustButton('-${formatMoney(small, currency)}', -small),
            adjustButton('+${formatMoney(small, currency)}', small),
            adjustButton('+${formatMoney(large, currency)}', large),
            if (adjustment != 0)
              TextButton(
                onPressed: cart.resetAdjustment,
                child: const Text('Reset'),
              ),
          ],
        ),
      ],
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.item, required this.cart});

  final CartItem item;
  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final productCurrency = item.product.currency;
    final sellsOneAtATime = item.product.isSerialized && item.product.quantity <= 1;
    final canIncrement = !sellsOneAtATime && item.quantity < item.product.quantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => cart.removeItem(item.product.id),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Text(
          '${formatMoney(item.product.sellingPrice, productCurrency)} each',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => cart.decrement(item.product.id),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${item.quantity}'),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: canIncrement
                  ? () => cart.increment(item.product.id)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
            const Spacer(),
            PriceText(
              item.lineTotal,
              currency: productCurrency,
              crossAxisAlignment: CrossAxisAlignment.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}
