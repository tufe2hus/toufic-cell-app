import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/shopping_list_item_model.dart';
import '../../providers/app_provider.dart';
import '../../utils/export_utils.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/role_guard.dart';

/// Goods the owner intends to bring/restock soon — a plain checklist kept
/// separate from [StockIntake] (which only logs stock already brought in).
/// Printable via [printShoppingList] so it can be taken along on the
/// supplier run.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(allowAdmin: true, child: _ShoppingListView());
  }
}

class _ShoppingListView extends StatelessWidget {
  const _ShoppingListView();

  Future<void> _addItem(BuildContext context, AppProvider provider) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AddShoppingItemDialog(),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _print(BuildContext context, List<ShoppingListItem> items) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await printShoppingList(items);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to print: $error')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    AppProvider provider,
    ShoppingListItem item,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Remove "${item.name}"?',
      message: 'This removes it from the shopping list. This cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteShoppingListItem(item);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final items = provider.shoppingListItems;
    final pending = items.where((item) => !item.isBought).toList();
    final bought = items.where((item) => item.isBought).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goods to bring'),
        actions: [
          IconButton(
            onPressed: items.isEmpty ? null : () => _print(context, items),
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print list',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context, provider),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Write down what you need to bring or restock on your next '
            'supplier run, then tick items off (or print the list) once '
            "you're on your way.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty && bought.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nothing on the list yet. Tap "Add item" to start.'),
              ),
            )
          else ...[
            if (pending.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Everything on the list has been bought.'),
                ),
              )
            else
              ...pending.map(
                (item) => _ShoppingListTile(
                  item: item,
                  onToggle: () =>
                      provider.setShoppingListItemBought(item, true),
                  onDelete: () => _delete(context, provider, item),
                ),
              ),
            if (bought.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Bought',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...bought.map(
                (item) => _ShoppingListTile(
                  item: item,
                  onToggle: () =>
                      provider.setShoppingListItemBought(item, false),
                  onDelete: () => _delete(context, provider, item),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ShoppingListTile extends StatelessWidget {
  const _ShoppingListTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final ShoppingListItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: item.isBought ? Colors.green.withValues(alpha: 0.14) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: item.isBought
            ? BorderSide(color: Colors.green.shade400, width: 1.4)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isBought,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          '${item.name} ×${item.quantity}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: item.isBought ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.note.isNotEmpty) Text(item.note),
            Text(
              DateFormat('dd/MM/yyyy').format(item.createdAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
        ),
      ),
    );
  }
}

class _AddShoppingItemDialog extends StatefulWidget {
  const _AddShoppingItemDialog();

  @override
  State<_AddShoppingItemDialog> createState() =>
      _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<_AddShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppProvider>().createShoppingListItem(
        name: _nameController.text.trim(),
        quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
        note: _noteController.text.trim(),
      );
      navigator.pop('Added to the shopping list.');
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to add item: $error')),
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
      title: const Text('Add goods to bring'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Item name is required.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid quantity.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
            ],
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
