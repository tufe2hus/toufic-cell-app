import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/currency.dart';
import '../../models/storefront_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/role_guard.dart';

/// Admin editor for the public storefront website (toufic-cell-stream.web.app)
/// — the products/prices and branding shown there are edited here instead of
/// hand-editing the site's code, then read live off Firestore by the site.
class StorefrontManagementScreen extends StatelessWidget {
  const StorefrontManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(
      allowAdmin: true,
      child: _StorefrontManagementView(),
    );
  }
}

class _StorefrontManagementView extends StatefulWidget {
  const _StorefrontManagementView();

  @override
  State<_StorefrontManagementView> createState() =>
      _StorefrontManagementViewState();
}

class _StorefrontManagementViewState
    extends State<_StorefrontManagementView> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final products = [...provider.storefrontProducts]
      ..sort((a, b) => a.order.compareTo(b.order));
    final categories = [...provider.storefrontCategories]
      ..sort((a, b) => a.order.compareTo(b.order));
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    Widget productTile(StorefrontProduct product) => _StorefrontProductTile(
      product: product,
      currency: provider.storefrontSettings.currency,
      onToggleActive: (isActive) => provider.updateStorefrontProduct(
        StorefrontProduct(
          id: product.id,
          name: product.name,
          description: product.description,
          logo: product.logo,
          price: product.price,
          duration: product.duration,
          categoryId: product.categoryId,
          order: product.order,
          isActive: isActive,
        ),
      ),
      onEdit: () => _showProductDialog(context, provider, existing: product),
      onDelete: () => _confirmDeleteProduct(context, provider, product),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Storefront website')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, provider),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'toufic-cell-stream.web.app',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Changes here appear on the live site the next time a '
                    'visitor loads it — no redeploy needed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _showSettingsDialog(context, provider),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Store name & WhatsApp number'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Group products into sections on the storefront, e.g. '
                    '"Streaming" and "Gift Cards".',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in categories)
                        InputChip(
                          label: Text(category.name),
                          onPressed: () =>
                              _showCategoryDialog(context, provider, existing: category),
                          onDeleted: () =>
                              _confirmDeleteCategory(context, provider, category),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add category'),
                        onPressed: () => _showCategoryDialog(context, provider),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No products yet — add one so the storefront has something to sell.',
                ),
              ),
            )
          else ...[
            for (final category in categories) ...[
              if (products.any((p) => p.categoryId == category.id)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ...products
                    .where((p) => p.categoryId == category.id)
                    .map(productTile),
                const SizedBox(height: 12),
              ],
            ],
            if (products.any(
              (p) => !categoryNames.containsKey(p.categoryId),
            )) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Uncategorized',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...products
                  .where((p) => !categoryNames.containsKey(p.categoryId))
                  .map(productTile),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    AppProvider provider,
    StorefrontProduct product,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete ${product.name}?',
      message: 'This removes it from the storefront website immediately.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteStorefrontProduct(product);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $error')),
        );
      }
    }
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    AppProvider provider,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _StorefrontSettingsDialog(
        settings: provider.storefrontSettings,
        provider: provider,
      ),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _showProductDialog(
    BuildContext context,
    AppProvider provider, {
    StorefrontProduct? existing,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _StorefrontProductDialog(
        provider: provider,
        existing: existing,
        nextOrder: provider.storefrontProducts.length,
      ),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    AppProvider provider, {
    StorefrontCategory? existing,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _StorefrontCategoryDialog(
        provider: provider,
        existing: existing,
        nextOrder: provider.storefrontCategories.length,
      ),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    AppProvider provider,
    StorefrontCategory category,
  ) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete "${category.name}"?',
      message:
          'Products in this category move to "Uncategorized" instead of '
          'being deleted.',
    );
    if (!confirmed) return;
    try {
      await provider.deleteStorefrontCategory(category);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $error')),
        );
      }
    }
  }
}

class _StorefrontProductTile extends StatelessWidget {
  const _StorefrontProductTile({
    required this.product,
    required this.currency,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final StorefrontProduct product;
  final Currency currency;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
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
            CircleAvatar(
              child: Text(
                product.logo.isEmpty
                    ? '?'
                    : product.logo.characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (product.description.isNotEmpty)
                    Text(product.description),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMoney(product.price, currency)} / ${product.duration}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Switch(
                  value: product.isActive,
                  onChanged: onToggleActive,
                ),
                Text(
                  product.isActive ? 'Visible' : 'Hidden',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
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

class _StorefrontSettingsDialog extends StatefulWidget {
  const _StorefrontSettingsDialog({
    required this.settings,
    required this.provider,
  });

  final StorefrontSettings settings;
  final AppProvider provider;

  @override
  State<_StorefrontSettingsDialog> createState() =>
      _StorefrontSettingsDialogState();
}

class _StorefrontSettingsDialogState
    extends State<_StorefrontSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeNameController;
  late final TextEditingController _whatsappController;
  late Currency _currency;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(text: widget.settings.storeName);
    _whatsappController = TextEditingController(text: widget.settings.whatsappNumber);
    _currency = widget.settings.currency;
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    try {
      await widget.provider.updateStorefrontSettings(
        StorefrontSettings(
          storeName: _storeNameController.text.trim(),
          whatsappNumber: _whatsappController.text.trim(),
          currency: _currency,
        ),
      );
      navigator.pop('Storefront settings updated.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $error')),
        );
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
      title: const Text('Storefront settings'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _storeNameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Store name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Store name is required.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp number',
                  hintText: 'Country code + number, e.g. 96103123456',
                ),
                validator: (value) {
                  final digits = (value ?? '').trim();
                  if (digits.isEmpty) return 'WhatsApp number is required.';
                  if (!RegExp(r'^[0-9]+$').hasMatch(digits)) {
                    return 'Digits only — no + or spaces.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
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

class _StorefrontCategoryDialog extends StatefulWidget {
  const _StorefrontCategoryDialog({
    required this.provider,
    required this.nextOrder,
    this.existing,
  });

  final AppProvider provider;
  final int nextOrder;
  final StorefrontCategory? existing;

  @override
  State<_StorefrontCategoryDialog> createState() =>
      _StorefrontCategoryDialogState();
}

class _StorefrontCategoryDialogState extends State<_StorefrontCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.provider.createStorefrontCategory(
          name: _nameController.text.trim(),
          order: widget.nextOrder,
        );
      } else {
        await widget.provider.updateStorefrontCategory(
          StorefrontCategory(
            id: existing.id,
            name: _nameController.text.trim(),
            order: existing.order,
          ),
        );
      }
      navigator.pop(_isEditing ? 'Category updated.' : 'Category added.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $error')),
        );
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
      title: Text(_isEditing ? 'Edit category' : 'Add category'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Category name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Category name is required.'
                : null,
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

class _StorefrontProductDialog extends StatefulWidget {
  const _StorefrontProductDialog({
    required this.provider,
    required this.nextOrder,
    this.existing,
  });

  final AppProvider provider;
  final int nextOrder;
  final StorefrontProduct? existing;

  @override
  State<_StorefrontProductDialog> createState() =>
      _StorefrontProductDialogState();
}

class _StorefrontProductDialogState extends State<_StorefrontProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _logoController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;
  late String _categoryId;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _logoController = TextEditingController(
      text: existing?.logo ?? '',
    );
    _priceController = TextEditingController(
      text: existing == null ? '' : existing.price.toString(),
    );
    _durationController = TextEditingController(
      text: existing?.duration ?? '1 month',
    );
    // Falls back to "Uncategorized" if the product's saved category no
    // longer exists (e.g. deleted between page loads), so the dropdown's
    // initial value always matches one of its own items.
    final categoryId = existing?.categoryId ?? '';
    _categoryId = widget.provider.storefrontCategories.any((c) => c.id == categoryId)
        ? categoryId
        : '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _logoController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.tryParse(_priceController.text.trim()) ?? -1;
    if (price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    try {
      final existing = widget.existing;
      final logo = _logoController.text.trim().isEmpty
          ? _nameController.text.trim().characters.take(1).toString()
          : _logoController.text.trim();
      if (existing == null) {
        await widget.provider.createStorefrontProduct(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          logo: logo,
          price: price,
          duration: _durationController.text.trim(),
          categoryId: _categoryId,
          order: widget.nextOrder,
        );
      } else {
        await widget.provider.updateStorefrontProduct(
          StorefrontProduct(
            id: existing.id,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            logo: logo,
            price: price,
            duration: _durationController.text.trim(),
            categoryId: _categoryId,
            order: existing.order,
            isActive: existing.isActive,
          ),
        );
      }
      navigator.pop(_isEditing ? 'Product updated.' : 'Product added.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $error')),
        );
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
      title: Text(_isEditing ? 'Edit product' : 'Add product'),
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
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Price'),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          if (parsed == null || parsed < 0) {
                            return 'Enter a valid price.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          hintText: 'e.g. 1 month',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Duration is required.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _logoController,
                  maxLength: 2,
                  decoration: const InputDecoration(
                    labelText: 'Badge letter (optional)',
                    hintText: 'Defaults to the first letter of the name',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Uncategorized')),
                    for (final category in widget.provider.storefrontCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value ?? ''),
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
