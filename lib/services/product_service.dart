import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';

class ProductService {
  ProductService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _publicProductsRef =>
      _firestore.collection('product_catalog');

  CollectionReference<Map<String, dynamic>> get _productIndexesRef =>
      _firestore.collection('product_indexes');

  String newProductId() => _productsRef.doc().id;

  // Both admin and regular users read from the same 'products' collection.
  // Admin stream returns all products; the public stream filters inactive ones
  // client-side so no composite index (isActive + createdAt) is required.
  Stream<List<Product>> productsStream() {
    return _productsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Product>> publicProductsStream() {
    return _productsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Product.fromMap(doc.data(), doc.id))
              .where((product) => product.isActive)
              .toList(),
        );
  }

  Future<void> createProduct(Product product) async {
    final normalizedBarcode = product.barcode.trim().toLowerCase();
    final normalizedSerial = product.serialNumber.trim().toLowerCase();
    final barcodeRef = normalizedBarcode.isEmpty
        ? null
        : _productIndexesRef.doc('barcode::$normalizedBarcode');
    final serialRef = normalizedSerial.isEmpty
        ? null
        : _productIndexesRef.doc('serial::$normalizedSerial');

    await _firestore.runTransaction((transaction) async {
      if (barcodeRef != null) {
        final barcodeSnapshot = await transaction.get(barcodeRef);
        if (barcodeSnapshot.exists) {
          throw Exception('Barcode already exists.');
        }
      }

      if (serialRef != null) {
        final serialSnapshot = await transaction.get(serialRef);
        if (serialSnapshot.exists) {
          throw Exception('Serial number already exists.');
        }
      }

      final now = FieldValue.serverTimestamp();
      final privatePayload = product.toMap();
      privatePayload['createdAt'] = now;
      privatePayload['updatedAt'] = now;
      final publicPayload = product.toPublicMap();
      publicPayload['createdAt'] = now;
      publicPayload['updatedAt'] = now;

      transaction.set(_productsRef.doc(product.id), privatePayload);
      transaction.set(_publicProductsRef.doc(product.id), publicPayload);

      if (barcodeRef != null) {
        transaction.set(barcodeRef, {
          'type': 'barcode',
          'value': normalizedBarcode,
          'productId': product.id,
          'createdAt': now,
        });
      }

      if (serialRef != null) {
        transaction.set(serialRef, {
          'type': 'serial',
          'value': normalizedSerial,
          'productId': product.id,
          'createdAt': now,
        });
      }
    });
  }

  Future<void> updateProduct(Product product) async {
    final normalizedBarcode = product.barcode.trim().toLowerCase();
    final normalizedSerial = product.serialNumber.trim().toLowerCase();
    final productRef = _productsRef.doc(product.id);
    final publicProductRef = _publicProductsRef.doc(product.id);

    await _firestore.runTransaction((transaction) async {
      final existingSnapshot = await transaction.get(productRef);
      if (!existingSnapshot.exists) {
        throw StateError('Product not found for update.');
      }

      final existing = Product.fromMap(
        existingSnapshot.data() ?? <String, dynamic>{},
        existingSnapshot.id,
      );
      final oldBarcode = existing.barcode.trim().toLowerCase();
      final oldSerial = existing.serialNumber.trim().toLowerCase();
      final newBarcodeRef = normalizedBarcode.isEmpty
          ? null
          : _productIndexesRef.doc('barcode::$normalizedBarcode');
      final newSerialRef = normalizedSerial.isEmpty
          ? null
          : _productIndexesRef.doc('serial::$normalizedSerial');

      if (newBarcodeRef != null && normalizedBarcode != oldBarcode) {
        final barcodeSnapshot = await transaction.get(newBarcodeRef);
        final productId = barcodeSnapshot.data()?['productId'] as String?;
        if (barcodeSnapshot.exists && productId != product.id) {
          throw Exception('Barcode already exists.');
        }
      }

      if (newSerialRef != null && normalizedSerial != oldSerial) {
        final serialSnapshot = await transaction.get(newSerialRef);
        final productId = serialSnapshot.data()?['productId'] as String?;
        if (serialSnapshot.exists && productId != product.id) {
          throw Exception('Serial number already exists.');
        }
      }

      final privatePayload = product.toMap();
      privatePayload.remove('createdAt');
      privatePayload['updatedAt'] = FieldValue.serverTimestamp();
      final publicPayload = product.toPublicMap();
      publicPayload.remove('createdAt');
      publicPayload['updatedAt'] = FieldValue.serverTimestamp();

      transaction.update(productRef, privatePayload);
      transaction.set(publicProductRef, publicPayload, SetOptions(merge: true));

      if (oldBarcode != normalizedBarcode) {
        if (oldBarcode.isNotEmpty) {
          transaction.delete(_productIndexesRef.doc('barcode::$oldBarcode'));
        }
        if (newBarcodeRef != null) {
          transaction.set(newBarcodeRef, {
            'type': 'barcode',
            'value': normalizedBarcode,
            'productId': product.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (oldSerial != normalizedSerial) {
        if (oldSerial.isNotEmpty) {
          transaction.delete(_productIndexesRef.doc('serial::$oldSerial'));
        }
        if (newSerialRef != null) {
          transaction.set(newSerialRef, {
            'type': 'serial',
            'value': normalizedSerial,
            'productId': product.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  Future<void> deleteProduct(String id) async {
    final existingSnapshot = await _productsRef.doc(id).get();
    final batch = _firestore.batch();
    batch.delete(_productsRef.doc(id));
    batch.delete(_publicProductsRef.doc(id));
    if (existingSnapshot.exists) {
      final existing = Product.fromMap(
        existingSnapshot.data() ?? <String, dynamic>{},
        existingSnapshot.id,
      );
      final normalizedBarcode = existing.barcode.trim().toLowerCase();
      final normalizedSerial = existing.serialNumber.trim().toLowerCase();
      if (normalizedBarcode.isNotEmpty) {
        batch.delete(_productIndexesRef.doc('barcode::$normalizedBarcode'));
      }
      if (normalizedSerial.isNotEmpty) {
        batch.delete(_productIndexesRef.doc('serial::$normalizedSerial'));
      }
    }
    await batch.commit();
  }

  Future<void> updateProductStock({
    required String id,
    required int quantity,
    required bool isActive,
  }) async {
    final payload = <String, dynamic>{
      'quantity': quantity,
      'stock': quantity,
      'isSold': quantity <= 0,
      'isActive': isActive,
      'updatedAt': Timestamp.now(),
    };
    final batch = _firestore.batch();
    batch.update(_productsRef.doc(id), payload);
    batch.update(_publicProductsRef.doc(id), payload);
    await batch.commit();
  }

  Future<Product?> getProduct(String id) async {
    final snapshot = await _productsRef.doc(id).get();
    if (!snapshot.exists) {
      return null;
    }
    return Product.fromMap(snapshot.data() ?? {}, snapshot.id);
  }
}
