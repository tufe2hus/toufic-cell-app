import 'package:cloud_firestore/cloud_firestore.dart';

/// Store-wide settings shared by every user, currently just the USD→LBP
/// exchange rate the admin maintains for displaying Lebanese Lira prices.
class SettingsService {
  SettingsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const double defaultUsdToLbpRate = 90000;

  DocumentReference<Map<String, dynamic>> get _currencyRef =>
      _firestore.collection('settings').doc('currency');

  Stream<double> usdToLbpRateStream() {
    return _currencyRef.snapshots().map((snapshot) {
      final rate = snapshot.data()?['usdToLbpRate'];
      return rate is num ? rate.toDouble() : defaultUsdToLbpRate;
    });
  }

  Future<void> updateUsdToLbpRate(double rate) async {
    await _currencyRef.set({
      'usdToLbpRate': rate,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
