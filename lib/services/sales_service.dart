import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';

class SalesService {
  SalesService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _salesRef =>
      _firestore.collection('sales');

  CollectionReference<Map<String, dynamic>> get _publicSalesRef =>
      _firestore.collection('sales_public');

  Future<void> createSale(SaleRecord sale) async {
    final batch = _firestore.batch();
    batch.set(_salesRef.doc(sale.id), sale.toMap());
    batch.set(_publicSalesRef.doc(sale.id), sale.toPublicMap());
    await batch.commit();
  }

  Stream<List<SaleRecord>> salesStream() {
    return _salesRef
        .orderBy('soldAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SaleRecord.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<SaleRecord>> publicSalesStream() {
    return _publicSalesRef
        .orderBy('soldAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SaleRecord.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
