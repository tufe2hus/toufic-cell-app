import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_intake_model.dart';

/// Logs "goods brought into the store" events — see [StockIntake].
class StockIntakeService {
  StockIntakeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _intakesRef =>
      _firestore.collection('stock_intakes');

  String newIntakeId() => _intakesRef.doc().id;

  Stream<List<StockIntake>> intakesStream() {
    return _intakesRef.orderBy('createdAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StockIntake.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<void> createIntake(StockIntake intake) async {
    await _intakesRef.doc(intake.id).set(intake.toMap());
  }
}
