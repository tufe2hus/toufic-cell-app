import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';
import '../utils/phone_normalization.dart';

class Product {
  Product({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.serialNumber,
    required this.barcode,
    required this.categoryId,
    required this.categoryName,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.minimumStock,
    required this.description,
    required this.isSerialized,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.imageBase64,
    this.currency = Currency.usd,
  });

  final String id;
  final String name;
  final String normalizedName;
  final String serialNumber;
  final String barcode;
  final String categoryId;
  final String categoryName;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int minimumStock;
  final String description;
  final bool isSerialized;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  /// JPEG photo of the product, base64-encoded and stored inline in
  /// Firestore. Kept small (compressed client-side before saving) so it
  /// stays well under Firestore's 1 MiB document limit and avoids needing
  /// paid Firebase Storage.
  final String? imageBase64;
  /// Currency both [purchasePrice] and [sellingPrice] are denominated in.
  /// Defaults to USD for every pre-existing product, since all stored
  /// amounts were implicitly USD before currency selection was added.
  final Currency currency;

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;

  /// Quantity 0 = out of stock, quantity 1 = low stock, 2+ = normal.
  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity == 1;

  factory Product.fromMap(Map<String, dynamic> data, String id) {
    final quantity = data['quantity'] as int? ?? data['stock'] as int? ?? 0;
    final purchasePrice =
        (data['purchasePrice'] as num?)?.toDouble() ??
        (data['costPrice'] as num?)?.toDouble() ??
        0;
    final categoryName =
        data['categoryName'] as String? ?? data['category'] as String? ?? '';
    return Product(
      id: id,
      name: data['name'] as String? ?? '',
      normalizedName:
          data['normalizedName'] as String? ??
          (data['name'] as String? ?? '').trim().toLowerCase(),
      serialNumber: data['serialNumber'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      categoryName: categoryName,
      purchasePrice: purchasePrice,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      quantity: quantity,
      minimumStock: data['minimumStock'] as int? ?? 3,
      description: data['description'] as String? ?? '',
      isSerialized: data['isSerialized'] as bool? ?? false,
      isActive:
          data['isActive'] as bool? ?? !(data['isSold'] as bool? ?? false),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      imageBase64: data['imageBase64'] as String?,
      currency: Currency.fromStorage(data['currency'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'normalizedName': normalizedName,
    'serialNumber': serialNumber,
    'barcode': barcode,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'category': categoryName,
    'purchasePrice': purchasePrice,
    'costPrice': purchasePrice,
    'sellingPrice': sellingPrice,
    'quantity': quantity,
    'stock': quantity,
    'minimumStock': minimumStock,
    'description': description,
    'isSerialized': isSerialized,
    'isActive': isActive,
    'isSold': quantity <= 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'createdBy': createdBy,
    'imageBase64': imageBase64,
    'currency': currency.storageValue,
  };

  Map<String, dynamic> toPublicMap() => {
    'name': name,
    'normalizedName': normalizedName,
    'serialNumber': serialNumber,
    'barcode': barcode,
    'categoryId': categoryId,
    'categoryName': categoryName,
    'category': categoryName,
    'sellingPrice': sellingPrice,
    'quantity': quantity,
    'stock': quantity,
    'minimumStock': minimumStock,
    'isSerialized': isSerialized,
    'isActive': isActive,
    'isSold': quantity <= 0,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'createdBy': createdBy,
    'imageBase64': imageBase64,
    'currency': currency.storageValue,
  };
}

class CategoryModel {
  CategoryModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    required this.isActive,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  factory CategoryModel.fromMap(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      name: data['name'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'createdAt': createdAt,
    'createdBy': createdBy,
    'isActive': isActive,
  };
}

class Debtor {
  Debtor({
    required this.id,
    required this.name,
    required this.createdAt,
    this.phoneNumber = '',
    String normalizedPhone = '',
    this.note = '',
    this.theyOweMe = true,
    this.usdTotalDebtCents = 0,
    this.usdTotalPaidCents = 0,
    this.lbpTotalDebt = 0,
    this.lbpTotalPaid = 0,
    this.dueDate,
    this.invoiceCount = 0,
    this.updatedAt,
    this.lastPaymentAt,
    this.createdBy = '',
  }) : normalizedPhone = normalizedPhone.isNotEmpty
           ? normalizedPhone
           : normalizeLebanesePhone(phoneNumber);

  final String id;
  final String name;
  final String phoneNumber;
  final String normalizedPhone;
  final String note;
  final DateTime createdAt;
  final bool theyOweMe;
  /// USD ledger, in cents. LBP has no minor unit in everyday use, so its
  /// ledger is stored as whole Lira. The two currencies are never combined —
  /// a debtor can owe money in both at once, tracked independently.
  final int usdTotalDebtCents;
  final int usdTotalPaidCents;
  final int lbpTotalDebt;
  final int lbpTotalPaid;
  final DateTime? dueDate;
  final int invoiceCount;
  final DateTime? updatedAt;
  final DateTime? lastPaymentAt;
  final String createdBy;

  int get usdRemainingCents =>
      usdTotalDebtCents > usdTotalPaidCents ? usdTotalDebtCents - usdTotalPaidCents : 0;
  int get lbpRemaining => lbpTotalDebt > lbpTotalPaid ? lbpTotalDebt - lbpTotalPaid : 0;
  double get usdTotalDebt => usdTotalDebtCents / 100.0;
  double get usdTotalPaid => usdTotalPaidCents / 100.0;
  double get usdRemainingAmount => usdRemainingCents / 100.0;
  double get lbpTotalDebtAmount => lbpTotalDebt.toDouble();
  double get lbpTotalPaidAmount => lbpTotalPaid.toDouble();
  double get lbpRemainingAmount => lbpRemaining.toDouble();
  bool get hasUsdActivity => usdTotalDebtCents > 0;
  bool get hasLbpActivity => lbpTotalDebt > 0;
  bool get isSettled => usdRemainingCents <= 0 && lbpRemaining <= 0;

  /// Legacy USD-only aliases for call sites (dashboard tiles, older exports)
  /// that predate multi-currency support and only ever showed one figure.
  double get amount => usdTotalDebt;
  double get paidAmount => usdTotalPaid;
  double get remainingAmount => usdRemainingAmount;

  String get computedStatus {
    if (isSettled) {
      return 'paid';
    }
    if (usdTotalPaidCents == 0 && lbpTotalPaid == 0) {
      return 'unpaid';
    }
    final now = DateTime.now();
    if (dueDate != null &&
        dueDate!.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'overdue';
    }
    return 'partiallyPaid';
  }

  static int _legacyCents(
    Map<String, dynamic> data,
    List<String> centsKeys, {
    String? legacyAmountKey,
  }) {
    for (final key in centsKeys) {
      final value = data[key];
      if (value is num) {
        return value.toInt();
      }
    }
    if (legacyAmountKey != null) {
      final value = data[legacyAmountKey];
      if (value is num) {
        return (value.toDouble() * 100).round();
      }
    }
    return 0;
  }

  factory Debtor.fromMap(Map<String, dynamic> data, String id) {
    final phone = data['phoneNumber'] as String? ?? '';
    final storedNormalized = data['normalizedPhone'] as String?;
    return Debtor(
      id: id,
      name: data['name'] as String? ?? '',
      phoneNumber: phone,
      normalizedPhone: storedNormalized != null && storedNormalized.isNotEmpty
          ? storedNormalized
          : normalizeLebanesePhone(phone),
      note: data['note'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      theyOweMe: data['theyOweMe'] as bool? ?? true,
      usdTotalDebtCents: _legacyCents(
        data,
        ['usdTotalDebtCents', 'totalDebtCents'],
        legacyAmountKey: 'amount',
      ),
      usdTotalPaidCents: _legacyCents(
        data,
        ['usdTotalPaidCents', 'totalPaidCents', 'paidAmountCents'],
        legacyAmountKey: 'paidAmount',
      ),
      lbpTotalDebt: _legacyCents(data, ['lbpTotalDebt']),
      lbpTotalPaid: _legacyCents(data, ['lbpTotalPaid']),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      invoiceCount: (data['invoiceCount'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastPaymentAt: (data['lastPaymentAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'phoneNumber': phoneNumber,
    'normalizedPhone': normalizedPhone,
    'note': note,
    'createdAt': createdAt,
    'theyOweMe': theyOweMe,
    'usdTotalDebtCents': usdTotalDebtCents,
    'usdTotalPaidCents': usdTotalPaidCents,
    'lbpTotalDebt': lbpTotalDebt,
    'lbpTotalPaid': lbpTotalPaid,
    // Legacy USD-only mirror fields, kept so any code path still reading the
    // pre-multi-currency shape sees a coherent USD figure.
    'amount': usdTotalDebt,
    'paidAmount': usdTotalPaid,
    'totalPaid': usdTotalPaid,
    'totalDebtCents': usdTotalDebtCents,
    'totalPaidCents': usdTotalPaidCents,
    'remainingDebt': usdRemainingAmount,
    'dueDate': dueDate,
    'invoiceCount': invoiceCount,
    'status': computedStatus,
    'updatedAt': updatedAt ?? DateTime.now(),
    'lastPaymentAt': lastPaymentAt,
    'createdBy': createdBy,
  };
}

class SaleRecord {
  SaleRecord({
    required this.id,
    required this.productName,
    required this.serialNumber,
    required this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.discount,
    required this.profit,
    required this.soldAt,
    required this.createdBy,
    this.transactionId = '',
    this.productId = '',
    this.currency = Currency.usd,
  });

  final String id;
  final String productName;
  final String serialNumber;
  final String categoryName;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final double discount;
  final double profit;
  final DateTime soldAt;
  final String createdBy;
  /// Links this sale line back to the invoice/transaction it belongs to.
  final String transactionId;
  /// The product this sale decremented stock from, for restoring on delete.
  final String productId;
  /// Currency [unitPrice]/[totalAmount]/[profit] are denominated in.
  /// Defaults to USD for every pre-existing sale record.
  final Currency currency;

  factory SaleRecord.fromMap(Map<String, dynamic> data, String id) {
    return SaleRecord(
      id: id,
      productName: data['productName'] as String? ?? '',
      serialNumber: data['serialNumber'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      quantity: data['quantity'] as int? ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      discount: (data['discount'] as num?)?.toDouble() ?? 0,
      profit: (data['profit'] as num?)?.toDouble() ?? 0,
      soldAt: (data['soldAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      transactionId: data['transactionId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      currency: Currency.fromStorage(data['currency'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'serialNumber': serialNumber,
    'categoryName': categoryName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalAmount': totalAmount,
    'discount': discount,
    'profit': profit,
    'soldAt': soldAt,
    'createdBy': createdBy,
    'transactionId': transactionId,
    'productId': productId,
    'currency': currency.storageValue,
  };

  Map<String, dynamic> toPublicMap() => {
    'productName': productName,
    'serialNumber': serialNumber,
    'categoryName': categoryName,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalAmount': totalAmount,
    'soldAt': soldAt,
    'createdBy': createdBy,
    'transactionId': transactionId,
    'currency': currency.storageValue,
  };
}
