import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_record_models.dart';

class TransactionService {
  TransactionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactionsRef =>
      _firestore.collection('transactions');

  CollectionReference<Map<String, dynamic>> get _publicTransactionsRef =>
      _firestore.collection('transactions_public');

  Stream<List<TransactionRecord>> transactionsStream() {
    return _transactionsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionRecord.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createTransaction(TransactionRecord transaction) async {
    final batch = _firestore.batch();
    batch.set(_transactionsRef.doc(transaction.id), transaction.toMap());
    batch.set(
      _publicTransactionsRef.doc(transaction.id),
      transaction.toPublicMap(),
    );
    await batch.commit();
  }

  Stream<List<TransactionRecord>> publicTransactionsStream() {
    return _publicTransactionsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionRecord.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
