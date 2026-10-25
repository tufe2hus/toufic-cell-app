import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_model.dart';
import '../../providers/app_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/role_guard.dart';

class CategoriesManagementScreen extends StatelessWidget {
  const CategoriesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(
      allowAdmin: true,
      child: _CategoriesManagementView(),
    );
  }
}

class _CategoriesManagementView extends StatefulWidget {
  const _CategoriesManagementView();

  @override
  State<_CategoriesManagementView> createState() =>
      _CategoriesManagementViewState();
}

class _CategoriesManagementViewState extends State<_CategoriesManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _addCategory(AppProvider provider) async {
    if (_isSaving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();

    try {
      final category = CategoryModel(
        id: now.microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        createdAt: now,
        createdBy: provider.currentUser?.email ?? '',
        isActive: true,
      );
      await provider.createCategory(category);
      if (!mounted) {
        return;
      }
      setState(() {
        _nameController.clear();
      });
      _nameFocusNode.requestFocus();
      messenger.showSnackBar(
        const SnackBar(content: Text('Category added successfully.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to add category: $error')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add category',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Category name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Category name is required.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _addCategory(provider),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _addCategory(provider),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: const Text('Add category'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category list',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No categories available yet.'),
                    )
                  else
                    ...provider.categories.map(
                      (category) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(category.name),
                        subtitle: Text(
                          category.isActive ? 'Active' : 'Inactive',
                        ),
                        trailing: IconButton(
                          onPressed: () async {
                            final confirmed = await confirmDelete(
                              context,
                              title: 'Delete category?',
                              message:
                                  'This will permanently delete "${category.name}". This cannot be undone.',
                            );
                            if (!confirmed || !context.mounted) {
                              return;
                            }
                            try {
                              await provider.deleteCategory(category.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Deleted category ${category.name}.',
                                    ),
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete category: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
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
