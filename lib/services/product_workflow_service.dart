import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/currency.dart';
import '../models/product_model.dart';
import 'product_service.dart';

class ProductDraft {
  ProductDraft({
    required this.name,
    required this.serialNumber,
    required this.barcode,
    required this.categoryId,
    required this.categoryName,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.description,
    this.imageBase64,
    this.currency = Currency.usd,
  });

  final String name;
  final String serialNumber;
  final String barcode;
  final String categoryId;
  final String categoryName;
  final String purchasePrice;
  final String sellingPrice;
  final String quantity;
  final String description;
  final String? imageBase64;
  final Currency currency;
}

/// Base64-encoded images are stored inline in Firestore documents (to avoid
/// paid Firebase Storage), which cap out at 1 MiB. Leave generous headroom
/// for the rest of the product's fields and Firestore's own overhead.
const int maxProductImageBase64Length = 700 * 1024;

class ProductValidationException implements Exception {
  const ProductValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductWorkflowService {
  ProductWorkflowService({ProductService? productService})
    : _productService = productService ?? ProductService();

  final ProductService _productService;

  void validateProduct({
    required ProductDraft draft,
    required List<Product> existingProducts,
    String? existingProductId,
  }) {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const ProductValidationException('Product name is required.');
    }

    if (draft.categoryId.trim().isEmpty) {
      throw const ProductValidationException('Please select a category.');
    }

    final quantity = int.tryParse(draft.quantity.trim());
    if (quantity == null || quantity < 0) {
      throw const ProductValidationException('Enter a valid quantity.');
    }

    final purchasePrice = double.tryParse(draft.purchasePrice.trim());
    if (purchasePrice == null || purchasePrice < 0) {
      throw const ProductValidationException('Enter a valid purchase price.');
    }

    final sellingPrice = double.tryParse(draft.sellingPrice.trim());
    if (sellingPrice == null || sellingPrice < 0) {
      throw const ProductValidationException('Enter a valid selling price.');
    }

    final normalizedBarcode = _normalize(draft.barcode);
    if (normalizedBarcode.isNotEmpty) {
      final duplicateBarcode = existingProducts.any(
        (product) =>
            product.id != existingProductId &&
            _normalize(product.barcode) == normalizedBarcode,
      );
      if (duplicateBarcode) {
        throw const ProductValidationException('Barcode already exists.');
      }
    }

    final normalizedSerial = _normalize(draft.serialNumber);
    if (normalizedSerial.isNotEmpty) {
      final duplicateSerial = existingProducts.any(
        (product) =>
            product.id != existingProductId &&
            _normalize(product.serialNumber) == normalizedSerial,
      );
      if (duplicateSerial) {
        throw const ProductValidationException('Serial number already exists.');
      }
    }

    final imageLength = draft.imageBase64?.length ?? 0;
    if (imageLength > maxProductImageBase64Length) {
      throw const ProductValidationException(
        'Photo is too large even after compression. Try a smaller photo.',
      );
    }
  }

  Product buildProduct({
    required ProductDraft draft,
    required String productId,
    required String actor,
    Product? existing,
  }) {
    final trimmedName = draft.name.trim();
    final trimmedSerial = draft.serialNumber.trim();
    final parsedQuantity = int.parse(draft.quantity.trim());

    return Product(
      id: productId,
      name: trimmedName,
      normalizedName: trimmedName.toLowerCase(),
      serialNumber: trimmedSerial,
      barcode: draft.barcode.trim(),
      categoryId: draft.categoryId.trim(),
      categoryName: draft.categoryName.trim(),
      purchasePrice: double.parse(draft.purchasePrice.trim()),
      sellingPrice: double.parse(draft.sellingPrice.trim()),
      quantity: parsedQuantity,
      minimumStock: existing?.minimumStock ?? 3,
      description: draft.description.trim().isEmpty
          ? existing?.description ?? ''
          : draft.description.trim(),
      // A serial number only implies "sold one at a time" when there's
      // genuinely a single unit in stock. A serial/reference code on a
      // bulk-stocked item (e.g. phone covers) shouldn't cap the cart at 1.
      isSerialized: trimmedSerial.isNotEmpty && parsedQuantity <= 1,
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: existing?.createdBy.isNotEmpty == true
          ? existing!.createdBy
          : actor,
      imageBase64: draft.imageBase64,
      currency: draft.currency,
    );
  }

  Future<Product> saveProduct({
    required ProductDraft draft,
    required List<Product> existingProducts,
    required String actor,
    Product? existing,
  }) async {
    validateProduct(
      draft: draft,
      existingProducts: existingProducts,
      existingProductId: existing?.id,
    );

    final productId = existing?.id ?? _productService.newProductId();

    try {
      final product = buildProduct(
        draft: draft,
        productId: productId,
        actor: actor,
        existing: existing,
      );

      if (existing == null) {
        await _productService.createProduct(product);
      } else {
        await _productService.updateProduct(product);
      }

      return product;
    } on ProductValidationException {
      rethrow;
    } on FirebaseException catch (error) {
      throw ProductValidationException(
        error.message ?? 'A Firebase error occurred while saving the product.',
      );
    } catch (error) {
      throw ProductValidationException(_readableError(error));
    }
  }

  String _normalize(String value) => value.trim().toLowerCase();

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
}
