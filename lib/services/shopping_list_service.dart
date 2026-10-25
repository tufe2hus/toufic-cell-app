import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_list_item_model.dart';

class ShoppingListService {
  ShoppingListService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _itemsRef =>
      _firestore.collection('shopping_list_items');

  String newItemId() => _itemsRef.doc().id;

  Stream<List<ShoppingListItem>> itemsStream() {
    return _itemsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShoppingListItem.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createItem(ShoppingListItem item) async {
    await _itemsRef.doc(item.id).set(item.toMap());
  }

  Future<void> setBought(String id, bool isBought) async {
    await _itemsRef.doc(id).update({'isBought': isBought});
  }

  Future<void> deleteItem(String id) async {
    await _itemsRef.doc(id).delete();
  }
}
