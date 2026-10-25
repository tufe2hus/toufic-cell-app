import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/currency.dart';
import '../../models/product_model.dart';
import '../../providers/app_provider.dart';
import '../../services/image_compression.dart';
import '../../services/product_workflow_service.dart' show maxProductImageBase64Length;
import '../../utils/barcode_scanner.dart';
import '../../utils/camera_capture.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/role_guard.dart';
import '../maintenance/maintenance_management_screen.dart';
import 'categories_management_screen.dart';

class ProductManagementScreen extends StatelessWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleGuard(allowAdmin: true, child: _ProductManagementView());
  }
}

class _ProductManagementView extends StatefulWidget {
  const _ProductManagementView();

  @override
  State<_ProductManagementView> createState() => _ProductManagementViewState();
}

class _ProductManagementViewState extends State<_ProductManagementView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final query = _searchController.text.trim().toLowerCase();
    final filteredProducts = provider.products.where((product) {
      if (query.isEmpty) {
        return true;
      }
      return product.name.toLowerCase().contains(query) ||
          product.serialNumber.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.categoryName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product management'),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategoriesManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Maintenance / Repair jobs',
            icon: const Icon(Icons.build_circle_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MaintenanceManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, provider),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Add product'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    'Products',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search product, serial, barcode, category',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No products found.'),
                    )
                  else
                    ...filteredProducts.map(
                      (product) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: product.hasImage
                                ? MemoryImage(base64Decode(product.imageBase64!))
                                : null,
                            child: product.hasImage
                                ? null
                                : Text(
                                    product.name.isEmpty
                                        ? '?'
                                        : product.name[0].toUpperCase(),
                                  ),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.categoryName.isEmpty ? 'Uncategorized' : product.categoryName} • Qty ${product.quantity} • ${product.serialNumber}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                onPressed: () => _showProductDialog(
                                  context,
                                  provider,
                                  existing: product,
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final confirmed = await confirmDelete(
                                    context,
                                    title: 'Delete product?',
                                    message:
                                        'This will permanently delete "${product.name}". This cannot be undone.',
                                  );
                                  if (confirmed && context.mounted) {
                                    await provider.deleteProduct(product.id);
                                  }
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
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

  Future<void> _showProductDialog(
    BuildContext context,
    AppProvider provider, {
    Product? existing,
  }) async {
    if (provider.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one category before products.'),
        ),
      );
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _ProductDialog(provider: provider, existing: existing),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.provider, this.existing});

  final AppProvider provider;
  final Product? existing;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocusNode = FocusNode();
  late final TextEditingController _nameController;
  late final TextEditingController _serialController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _purchaseController;
  late final TextEditingController _sellingController;
  late final TextEditingController _quantityController;
  late String _selectedCategoryId;
  String? _imageBase64;
  bool _isSaving = false;
  bool _isProcessingImage = false;
  late Currency _selectedCurrency;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _imageBase64 = existing?.imageBase64;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _serialController = TextEditingController(
      text: existing?.serialNumber ?? '',
    );
    _barcodeController = TextEditingController(text: existing?.barcode ?? '');
    _purchaseController = TextEditingController(
      text: existing == null ? '' : existing.purchasePrice.toString(),
    );
    _sellingController = TextEditingController(
      text: existing == null ? '' : existing.sellingPrice.toString(),
    );
    _quantityController = TextEditingController(
      text: existing == null ? '' : existing.quantity.toString(),
    );
    _selectedCategoryId =
        existing?.categoryId ?? widget.provider.categories.first.id;
    _selectedCurrency = existing?.currency ?? Currency.usd;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _barcodeController.dispose();
    _purchaseController.dispose();
    _sellingController.dispose();
    _quantityController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanToController(TextEditingController controller) async {
    final scannedValue = await scanBarcode(context);
    if (scannedValue != null) {
      controller.text = scannedValue;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isSaving || _isProcessingImage) {
      return;
    }
    try {
      // file_picker's web implementation intermittently fails to open the
      // native picker on iOS Safari/Chrome, so web uses a hand-rolled
      // <input type=file> instead (same technique as the camera button).
      // Native platforms keep using file_picker, which works correctly there.
      final Uint8List? bytes = usesDirectGalleryPicker
          ? await pickImageFromGallery()
          : (await FilePicker.platform.pickFiles(
              type: FileType.image,
              withData: true,
            ))?.files.single.bytes;
      if (bytes == null) {
        return;
      }
      await _useImageBytes(bytes);
    } catch (error) {
      _handleImageError(error);
    }
  }

  Future<void> _takePhoto() async {
    if (_isSaving || _isProcessingImage) {
      return;
    }
    try {
      final bytes = await captureImageFromCamera();
      if (bytes == null) {
        return;
      }
      await _useImageBytes(bytes);
    } catch (error) {
      _handleImageError(error);
    }
  }

  Future<void> _useImageBytes(Uint8List bytes) async {
    setState(() => _isProcessingImage = true);
    final base64Image = await compute(compressImageToBase64, bytes);
    if (base64Image.length > maxProductImageBase64Length) {
      throw const FormatException(
        'Photo is too large even after compression.',
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _imageBase64 = base64Image;
      _isProcessingImage = false;
    });
  }

  void _handleImageError(Object error) {
    debugPrint('Product photo pick failed: $error');
    if (!mounted) {
      return;
    }
    setState(() => _isProcessingImage = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not use that photo: ${_readableError(error)}'),
      ),
    );
  }

  void _removeImage() {
    setState(() => _imageBase64 = null);
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.provider.saveProduct(
        existing: widget.existing,
        name: _nameController.text,
        serialNumber: _serialController.text,
        barcode: _barcodeController.text,
        categoryId: _selectedCategoryId,
        purchasePrice: _purchaseController.text,
        sellingPrice: _sellingController.text,
        quantity: _quantityController.text,
        description: widget.existing?.description ?? '',
        imageBase64: _imageBase64,
        currency: _selectedCurrency,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        _isEditing ? 'Product updated successfully' : 'Product added successfully',
      );
    } catch (error) {
      debugPrint('Product save failed: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save product: ${_readableError(error)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _readableError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    if (message.startsWith('Bad state: ')) {
      return message.substring('Bad state: '.length);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit product' : 'Add product'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImagePicker(context),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: !_isEditing,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Product name is required.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _serialController,
                  decoration: InputDecoration(
                    labelText: 'Serial number',
                    suffixIcon: IconButton(
                      tooltip: 'Scan serial',
                      onPressed: _isSaving
                          ? null
                          : () async {
                              try {
                                await _scanToController(_serialController);
                              } catch (error) {
                                debugPrint('Serial scan failed: $error');
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to open camera scanner on this device.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode',
                    suffixIcon: IconButton(
                      tooltip: 'Scan barcode',
                      onPressed: _isSaving
                          ? null
                          : () async {
                              try {
                                await _scanToController(_barcodeController);
                              } catch (error) {
                                debugPrint('Barcode scan failed: $error');
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to open camera scanner on this device.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.qr_code_scanner_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.provider.categories.any(
                        (category) => category.id == _selectedCategoryId,
                      )
                      ? _selectedCategoryId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.provider.categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategoryId = value ?? '';
                          });
                        },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _purchaseController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Purchase price',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid purchase price.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _sellingController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Selling price'),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid selling price.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid quantity.';
                    }
                    return null;
                  },
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
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Saving product...'),
                  ],
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    final hasImage = _imageBase64 != null && _imageBase64!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isSaving || _isProcessingImage ? null : _pickImage,
          child: Container(
            width: 88,
            height: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isProcessingImage
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasImage
                ? Image.memory(base64Decode(_imageBase64!), fit: BoxFit.cover)
                : Icon(
                    Icons.add_a_photo_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasImage ? 'Product photo' : 'No photo yet',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Stored directly in the database, so there is no extra cost.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _isSaving || _isProcessingImage
                        ? null
                        : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(hasImage ? 'Change photo' : 'Add photo'),
                  ),
                  if (supportsDirectCameraCapture)
                    TextButton.icon(
                      onPressed: _isSaving || _isProcessingImage
                          ? null
                          : _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Take photo'),
                    ),
                  if (hasImage)
                    TextButton.icon(
                      onPressed: _isSaving || _isProcessingImage
                          ? null
                          : _removeImage,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
