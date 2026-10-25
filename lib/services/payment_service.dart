import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_record_models.dart';

class PaymentService {
  PaymentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _paymentsRef =>
      _firestore.collection('payments');

  Stream<List<PaymentRecord>> paymentsStream() {
    return _paymentsRef
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentRecord.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> createPayment(PaymentRecord payment) async {
    await _paymentsRef.doc(payment.id).set(payment.toMap());
  }
}
