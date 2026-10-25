import 'package:cloud_firestore/cloud_firestore.dart';

/// A bill/expense the store paid (rent, electricity, supplier invoice, etc).
/// Logged from Admin Tools → Pay Bills; subtracted from the profit totals
/// for the period it was paid in (see AppProvider's profit getters).
class Bill {
  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.note,
    required this.paidAt,
    required this.paidBy,
  });

  final String id;
  final String name;
  final double amount;
  final String note;
  final DateTime paidAt;
  final String paidBy;

  factory Bill.fromMap(Map<String, dynamic> data, String id) {
    return Bill(
      id: id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: data['note'] as String? ?? '',
      paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidBy: data['paidBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'amount': amount,
    'note': note,
    'paidAt': paidAt,
    'paidBy': paidBy,
  };
}
