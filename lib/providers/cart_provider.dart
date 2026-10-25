import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/currency.dart';
import '../models/product_model.dart';

/// An existing debtor the current cart is being charged to, set from the
/// Debtors screen's "Add charge" button so the products picked next get
/// added to this same person's balance instead of prompting for a new
/// name/phone at checkout.
class DebtorChargeTarget {
  const DebtorChargeTarget({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;
}

class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  double _manualAdjustment = 0;
  DebtorChargeTarget? _chargeTarget;

  List<CartItem> get items => List.unmodifiable(_items);
  /// Set while the cart is being built up to add a charge to an existing
  /// debtor (see [DebtorChargeTarget]); `null` for a normal sale.
  DebtorChargeTarget? get chargeTarget => _chargeTarget;
  bool get isEmpty => _items.isEmpty;
  int get lineItemCount => _items.length;
  int get totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// The currency every item in the cart is priced in — items of a
  /// different currency are refused (see [canAdd]), so the cart always has
  /// exactly one currency once it has items. `null` when empty.
  Currency? get currency => _items.isEmpty ? null : _items.first.product.currency;

  /// Manual invoice-level adjustment (see requirement: quick +/-$1/+/-$5
  /// buttons). Never changes product price/stock — purely a charge applied
  /// on top of the line-item subtotal.
  double get manualAdjustment => _manualAdjustment;
  double get subtotal => totalAmount;
  double get finalTotal {
    final raw = totalAmount + _manualAdjustment;
    return raw < 0 ? 0 : raw;
  }

  /// True if [product] can be added without mixing currencies in the cart.
  bool canAdd(Product product) =>
      _items.isEmpty || currency == product.currency;

  /// Applies [delta] to the manual adjustment, clamped so the final total
  /// (subtotal + adjustment) never goes negative.
  void adjustManual(double delta) {
    final next = _manualAdjustment + delta;
    final rawFinal = totalAmount + next;
    _manualAdjustment = rawFinal < 0 ? -totalAmount : next;
    notifyListeners();
  }

  void resetAdjustment() {
    _manualAdjustment = 0;
    notifyListeners();
  }

  int quantityInCart(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    return index == -1 ? 0 : _items[index].quantity;
  }

  /// A serial number only means "sold one at a time" when there's genuinely
  /// a single unit in stock. Checking `quantity` here (rather than trusting
  /// `isSerialized` alone) keeps this correct even for products saved before
  /// bulk-stocked items with a serial/reference code were handled properly.
  bool _sellsOneAtATime(Product product) =>
      product.isSerialized && product.quantity <= 1;

  CartAddResult add(Product product) {
    if (product.quantity <= 0) {
      return CartAddResult.unavailable;
    }
    if (!canAdd(product)) {
      return CartAddResult.differentCurrency;
    }

    final index = _items.indexWhere((item) => item.product.id == product.id);

    if (index == -1) {
      _items = [..._items, CartItem(product: product, quantity: 1)];
      notifyListeners();
      return CartAddResult.added;
    }

    if (_sellsOneAtATime(product)) {
      return CartAddResult.cappedSerialized;
    }

    final existing = _items[index];
    if (existing.quantity >= product.quantity) {
      return CartAddResult.cappedByStock;
    }

    final updated = List<CartItem>.from(_items);
    updated[index] = existing.copyWith(quantity: existing.quantity + 1);
    _items = updated;
    notifyListeners();
    return CartAddResult.incremented;
  }

  CartAddResult increment(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return CartAddResult.unavailable;
    }
    final existing = _items[index];
    if (_sellsOneAtATime(existing.product)) {
      return CartAddResult.cappedSerialized;
    }
    if (existing.quantity >= existing.product.quantity) {
      return CartAddResult.cappedByStock;
    }
    final updated = List<CartItem>.from(_items);
    updated[index] = existing.copyWith(quantity: existing.quantity + 1);
    _items = updated;
    notifyListeners();
    return CartAddResult.incremented;
  }

  void decrement(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) {
      return;
    }
    final existing = _items[index];
    if (existing.quantity <= 1) {
      removeItem(productId);
      return;
    }
    final updated = List<CartItem>.from(_items);
    updated[index] = existing.copyWith(quantity: existing.quantity - 1);
    _items = updated;
    notifyListeners();
  }

  void removeItem(String productId) {
    _items = _items.where((item) => item.product.id != productId).toList();
    notifyListeners();
  }

  void clear() {
    _items = [];
    _manualAdjustment = 0;
    _chargeTarget = null;
    notifyListeners();
  }

  /// Starts a "charge to an existing debtor" session — the next products
  /// added and checked out will go straight to [target]'s balance.
  void startChargeFor(DebtorChargeTarget target) {
    _chargeTarget = target;
    notifyListeners();
  }

  /// Cancels a charge-to-debtor session without affecting cart contents,
  /// returning to a normal walk-in sale.
  void clearChargeTarget() {
    _chargeTarget = null;
    notifyListeners();
  }
}
