import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill_model.dart';

class BillService {
  BillService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  String newBillId() => _billsRef.doc().id;

  Stream<List<Bill>> billsStream() {
    return _billsRef
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Bill.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createBill(Bill bill) async {
    await _billsRef.doc(bill.id).set(bill.toMap());
  }

  Future<void> deleteBill(String id) async {
    await _billsRef.doc(id).delete();
  }
}
