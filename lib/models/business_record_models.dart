import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency.dart';

class TransactionRecord {
  TransactionRecord({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.paymentMethod,
    required this.productCount,
    required this.totalAmount,
    required this.profit,
    required this.createdBy,
    required this.createdAt,
    this.productNames = const <String>[],
    this.profitRealized = 0,
    this.currency = Currency.usd,
    double? subtotal,
    this.manualAdjustment = 0,
    this.customerPhone = '',
  }) : subtotal = subtotal ?? totalAmount;

  final String id;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final int productCount;
  /// The final amount actually charged — what reports and history should
  /// use. Equals [subtotal] plus [manualAdjustment].
  final double totalAmount;
  final double profit;
  final String createdBy;
  final DateTime createdAt;
  final List<String> productNames;
  /// How much of [profit] has actually been realized so far. Equals [profit]
  /// immediately for cash sales; for a 'Debt' [paymentMethod] this grows
  /// proportionally as the linked debtor pays, via [AppProvider.recordPayment].
  final double profitRealized;
  final Currency currency;
  /// Sum of line items before any manual invoice adjustment was applied.
  final double subtotal;
  /// Manual +/- adjustment applied at checkout (see requirement: quick
  /// +/-$1/+/-$5 buttons). Positive adds to the invoice, negative subtracts.
  /// Never changes product price/stock — purely an invoice-level charge.
  final double manualAdjustment;

  factory TransactionRecord.fromMap(Map<String, dynamic> data, String id) {
    final rawProducts = data['productNames'];
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
    return TransactionRecord(
      id: id,
      invoiceNumber: data['invoiceNumber'] as String? ?? id,
      customerName: data['customerName'] as String? ?? 'Walk-in Customer',
      customerPhone: data['customerPhone'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      productCount: data['productCount'] as int? ?? 0,
      totalAmount: totalAmount,
      profit: (data['profit'] as num?)?.toDouble() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productNames: rawProducts is List
          ? rawProducts.map((item) => item.toString()).toList()
          : const <String>[],
      profitRealized: (data['profitRealized'] as num?)?.toDouble() ?? 0,
      currency: Currency.fromStorage(data['currency'] as String?),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? totalAmount,
      manualAdjustment: (data['manualAdjustment'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'invoiceNumber': invoiceNumber,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'paymentMethod': paymentMethod,
    'productCount': productCount,
    'totalAmount': totalAmount,
    'profit': profit,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'productNames': productNames,
    'profitRealized': profitRealized,
    'currency': currency.storageValue,
    'subtotal': subtotal,
    'manualAdjustment': manualAdjustment,
  };

  Map<String, dynamic> toPublicMap() => {
    'invoiceNumber': invoiceNumber,
    'customerName': customerName,
    'paymentMethod': paymentMethod,
    'productCount': productCount,
    'totalAmount': totalAmount,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'productNames': productNames,
    'currency': currency.storageValue,
    'subtotal': subtotal,
    'manualAdjustment': manualAdjustment,
  };
}

class PaymentRecord {
  PaymentRecord({
    required this.id,
    required this.debtorId,
    required this.customerName,
    required this.amount,
    required this.note,
    required this.receivedBy,
    required this.paidAt,
    this.invoiceId = '',
    this.paymentMethod = 'cash',
    this.status = 'completed',
    this.createdAt,
    this.amountCents,
    this.remainingAfter,
    this.profit = 0,
    this.currency = Currency.usd,
  });

  final String id;
  final String debtorId;
  final String customerName;
  final double amount;
  final String note;
  final String receivedBy;
  final DateTime paidAt;
  final String invoiceId;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final int? amountCents;
  /// Which balance (USD or LBP) this payment reduces. A USD payment only
  /// ever reduces the debtor's USD balance, and vice versa.
  final Currency currency;

  /// Remaining debt balance after this payment was applied.
  /// Stored in Firestore so history can display it without re-computing.
  final double? remainingAfter;

  /// The share of the originating sale's profit this payment realized.
  /// Only non-zero when [invoiceId] links back to a cart-created debt sale;
  /// set server-side by [AppProvider.recordPayment].
  final double profit;

  int get resolvedAmountCents => amountCents ?? (amount * 100).round();

  /// USD payments are tracked in cents; LBP has no minor unit, so its
  /// "minor units" are just the whole-Lira amount.
  int get resolvedMinorUnits =>
      currency == Currency.usd ? resolvedAmountCents : amount.round();

  factory PaymentRecord.fromMap(Map<String, dynamic> data, String id) {
    return PaymentRecord(
      id: id,
      debtorId: data['debtorId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: data['note'] as String? ?? '',
      receivedBy: data['receivedBy'] as String? ?? '',
      paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      invoiceId: data['invoiceId'] as String? ?? '',
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      status: data['status'] as String? ?? 'completed',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      amountCents: (data['amountCents'] as num?)?.toInt(),
      remainingAfter: (data['remainingAfter'] as num?)?.toDouble(),
      profit: (data['profit'] as num?)?.toDouble() ?? 0,
      currency: Currency.fromStorage(data['currency'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'debtorId': debtorId,
    'customerName': customerName,
    'amount': amount,
    'amountCents': resolvedAmountCents,
    'note': note,
    'receivedBy': receivedBy,
    'paidAt': paidAt,
    'invoiceId': invoiceId,
    'paymentMethod': paymentMethod,
    'status': status,
    'createdAt': createdAt ?? paidAt,
    'currency': currency.storageValue,
    if (remainingAfter != null) 'remainingAfter': remainingAfter,
    'profit': profit,
  };
}

/// One line item within a [DebtorTransaction] of type 'debt' — a product the
/// customer took as part of that debt.
class DebtorTransactionProduct {
  const DebtorTransactionProduct({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory DebtorTransactionProduct.fromMap(Map<String, dynamic> data) {
    return DebtorTransactionProduct(
      productId: data['productId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (data['lineTotal'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'lineTotal': lineTotal,
  };
}

/// One entry in a debtor's `debtors/{id}/transactions` subcollection — the
/// detailed, per-event history shown on their profile (products taken, debt
/// added, or a payment received).
class DebtorTransaction {
  DebtorTransaction({
    required this.id,
    required this.type,
    required this.currency,
    required this.createdBy,
    required this.createdAt,
    this.products = const <DebtorTransactionProduct>[],
    this.subtotal = 0,
    this.manualAdjustment = 0,
    this.finalTotal = 0,
    this.paidAmount = 0,
    this.remainingBalanceAfter = 0,
    this.note = '',
    this.linkedTransactionId = '',
    this.profitCents = 0,
    this.profitRealizedCents = 0,
  });

  final String id;
  /// 'debt' (a new debt/products added) or 'payment' (money received).
  final String type;
  final Currency currency;
  final String createdBy;
  final DateTime createdAt;
  final List<DebtorTransactionProduct> products;
  final double subtotal;
  final double manualAdjustment;
  final double finalTotal;
  final double paidAmount;
  /// The debtor's remaining balance in [currency] immediately after this
  /// entry was applied.
  final double remainingBalanceAfter;
  final String note;
  /// The originating sale invoice (`transactions/{id}`), if this debt came
  /// from a product sale rather than a manual debt entry.
  final String linkedTransactionId;
  /// Full profit potential of this debt entry (0 for manual debts/payments),
  /// in [currency] minor units (see [Currency.toMinorUnits]).
  final int profitCents;
  /// How much of [profitCents] has been realized via payments so far.
  /// [AppProvider.recordPayment] allocates each payment across a debtor's
  /// outstanding debt entries oldest-first, incrementing this proportionally
  /// so reports only count profit once it's actually been collected.
  final int profitRealizedCents;

  bool get isPayment => type == 'payment';
  bool get isDebt => type == 'debt';
  int get remainingProfitCents => profitCents > profitRealizedCents
      ? profitCents - profitRealizedCents
      : 0;

  factory DebtorTransaction.fromMap(Map<String, dynamic> data, String id) {
    final rawProducts = data['products'];
    return DebtorTransaction(
      id: id,
      type: data['type'] as String? ?? 'debt',
      currency: Currency.fromStorage(data['currency'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      products: rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map(
                  (item) => DebtorTransactionProduct.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <DebtorTransactionProduct>[],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      manualAdjustment: (data['manualAdjustment'] as num?)?.toDouble() ?? 0,
      finalTotal: (data['finalTotal'] as num?)?.toDouble() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      remainingBalanceAfter:
          (data['remainingBalanceAfter'] as num?)?.toDouble() ?? 0,
      note: data['note'] as String? ?? '',
      linkedTransactionId: data['linkedTransactionId'] as String? ?? '',
      profitCents: (data['profitCents'] as num?)?.toInt() ?? 0,
      profitRealizedCents: (data['profitRealizedCents'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    'currency': currency.storageValue,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'products': products.map((product) => product.toMap()).toList(),
    'subtotal': subtotal,
    'manualAdjustment': manualAdjustment,
    'finalTotal': finalTotal,
    'paidAmount': paidAmount,
    'remainingBalanceAfter': remainingBalanceAfter,
    'note': note,
    'linkedTransactionId': linkedTransactionId,
    'profitCents': profitCents,
    'profitRealizedCents': profitRealizedCents,
  };
}
