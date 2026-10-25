import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/storefront_models.dart';

/// Reads/writes the public storefront website's product catalog and
/// branding settings — a separate Firestore collection from the store_app
/// product inventory (see [StorefrontProduct]).
class StorefrontService {
  StorefrontService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('storefront_products');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection('storefront_categories');

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('storefront_settings').doc('main');

  Stream<List<StorefrontProduct>> productsStream() {
    return _productsRef.orderBy('order').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StorefrontProduct.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Stream<List<StorefrontCategory>> categoriesStream() {
    return _categoriesRef.orderBy('order').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StorefrontCategory.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Stream<StorefrontSettings> settingsStream() {
    return _settingsRef.snapshots().map(
      (snapshot) => snapshot.data() == null
          ? const StorefrontSettings()
          : StorefrontSettings.fromMap(snapshot.data()!),
    );
  }

  String newProductId() => _productsRef.doc().id;

  String newCategoryId() => _categoriesRef.doc().id;

  Future<void> createProduct(StorefrontProduct product) async {
    await _productsRef.doc(product.id).set(product.toMap());
  }

  Future<void> updateProduct(StorefrontProduct product) async {
    await _productsRef.doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _productsRef.doc(id).delete();
  }

  Future<void> createCategory(StorefrontCategory category) async {
    await _categoriesRef.doc(category.id).set(category.toMap());
  }

  Future<void> updateCategory(StorefrontCategory category) async {
    await _categoriesRef.doc(category.id).update(category.toMap());
  }

  /// Deletes the category and un-assigns it from every product that had it
  /// (they fall back to "Uncategorized" rather than pointing at a
  /// now-missing category).
  Future<void> deleteCategory(String id) async {
    final affectedProducts = await _productsRef
        .where('categoryId', isEqualTo: id)
        .get();
    final batch = _firestore.batch();
    batch.delete(_categoriesRef.doc(id));
    for (final doc in affectedProducts.docs) {
      batch.update(doc.reference, {'categoryId': ''});
    }
    await batch.commit();
  }

  Future<void> updateSettings(StorefrontSettings settings) async {
    await _settingsRef.set(settings.toMap(), SetOptions(merge: true));
  }
}
