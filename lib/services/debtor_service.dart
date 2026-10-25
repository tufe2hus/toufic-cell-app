import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_record_models.dart';
import '../models/product_model.dart';

class DebtorService {
  DebtorService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _debtorsRef =>
      _firestore.collection('debtors');

  /// Maps a normalized phone number to the debtor doc it belongs to, so
  /// "does a debtor with this phone already exist" is a single strongly
  /// consistent document read (keyed deterministically by the phone itself)
  /// instead of a query — which is what lets debtor creation be de-duplicated
  /// atomically inside a Firestore transaction with no race window.
  CollectionReference<Map<String, dynamic>> get phoneIndexRef =>
      _firestore.collection('debtor_phone_index');

  CollectionReference<Map<String, dynamic>> transactionsRef(String debtorId) =>
      _debtorsRef.doc(debtorId).collection('transactions');

  DocumentReference<Map<String, dynamic>> debtorDoc(String id) =>
      _debtorsRef.doc(id);

  String newDebtorId() => _debtorsRef.doc().id;

  Stream<List<Debtor>> debtorsStream() {
    return _debtorsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Debtor.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Detailed per-event history for one debtor's profile — oldest first, so
  /// it reads top-to-bottom like a running statement.
  Stream<List<DebtorTransaction>> debtorTransactionsStream(String debtorId) {
    return transactionsRef(debtorId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DebtorTransaction.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createDebtor(Debtor debtor) async {
    await _debtorsRef.doc(debtor.id).set(debtor.toMap());
  }

  Future<void> updateDebtor(Debtor debtor) async {
    await _debtorsRef.doc(debtor.id).update(debtor.toMap());
  }

  Future<void> deleteDebtor(String id) async {
    await _debtorsRef.doc(id).delete();
  }
}
