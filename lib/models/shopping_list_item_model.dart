import 'package:cloud_firestore/cloud_firestore.dart';

/// A "goods to bring soon" entry — things the owner intends to buy or
/// restock on the next supplier run. Separate from [StockIntake], which only
/// logs stock already brought in; this is the forward-looking list.
class ShoppingListItem {
  ShoppingListItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    this.quantity = 1,
    this.note = '',
    this.isBought = false,
  });

  final String id;
  final String name;
  final int quantity;
  final String note;
  final bool isBought;
  final DateTime createdAt;
  final String createdBy;

  ShoppingListItem copyWith({bool? isBought}) {
    return ShoppingListItem(
      id: id,
      name: name,
      createdAt: createdAt,
      createdBy: createdBy,
      quantity: quantity,
      note: note,
      isBought: isBought ?? this.isBought,
    );
  }

  factory ShoppingListItem.fromMap(Map<String, dynamic> data, String id) {
    return ShoppingListItem(
      id: id,
      name: data['name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      note: data['note'] as String? ?? '',
      isBought: data['isBought'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'quantity': quantity,
    'note': note,
    'isBought': isBought,
    'createdAt': createdAt,
    'createdBy': createdBy,
  };
}
