import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';

/// A repair/maintenance service job (e.g. a phone repair) — its own record
/// type, independent of product inventory. Doesn't touch stock; tracks what
/// was done, what it cost, what the customer was charged, and how to reach
/// the customer.
class MaintenanceJob {
  MaintenanceJob({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.deviceDescription,
    required this.workDescription,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.date,
    required this.createdBy,
    this.currency = Currency.usd,
    this.note = '',
  });

  final String id;
  final String customerName;
  final String customerPhone;
  /// The phone/device being repaired (e.g. model or description).
  final String deviceDescription;
  /// What was done to the device.
  final String workDescription;
  /// What the repair cost (parts, etc).
  final double purchasePrice;
  /// What the customer was charged.
  final double sellingPrice;
  final DateTime date;
  final String createdBy;
  final Currency currency;
  final String note;

  double get profit => sellingPrice - purchasePrice;

  factory MaintenanceJob.fromMap(Map<String, dynamic> data, String id) {
    return MaintenanceJob(
      id: id,
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      deviceDescription: data['deviceDescription'] as String? ?? '',
      workDescription: data['workDescription'] as String? ?? '',
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      currency: Currency.fromStorage(data['currency'] as String?),
      note: data['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'customerName': customerName,
    'customerPhone': customerPhone,
    'deviceDescription': deviceDescription,
    'workDescription': workDescription,
    'purchasePrice': purchasePrice,
    'sellingPrice': sellingPrice,
    'date': date,
    'createdBy': createdBy,
    'currency': currency.storageValue,
    'note': note,
  };
}
