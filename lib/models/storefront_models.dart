import 'currency.dart';

/// One product/plan listed on the public storefront website
/// (toufic-cell-stream.web.app) — a completely separate catalog from the
/// store_app product inventory, since the storefront sells subscriptions
/// (Netflix, Shahid, ...) rather than physical stock, and shouldn't expose
/// internal cost/stock fields publicly.
class StorefrontProduct {
  const StorefrontProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.logo,
    required this.price,
    required this.duration,
    this.categoryId = '',
    this.order = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String description;
  /// Short text (usually one letter) shown in the product's logo badge.
  final String logo;
  final double price;
  final String duration;
  /// The [StorefrontCategory.id] this product is grouped under on the
  /// storefront, or empty for "Uncategorized".
  final String categoryId;
  /// Display order on the storefront, lowest first.
  final int order;
  /// Hidden from the public site while `false`, without deleting it.
  final bool isActive;

  factory StorefrontProduct.fromMap(Map<String, dynamic> data, String id) {
    return StorefrontProduct(
      id: id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      logo: data['logo'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      duration: data['duration'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'logo': logo,
    'price': price,
    'duration': duration,
    'categoryId': categoryId,
    'order': order,
    'isActive': isActive,
  };
}

/// A product grouping shown as its own section on the storefront (e.g.
/// "Streaming Subscriptions", "Gift Cards"), stored in the
/// `storefront_categories` collection.
class StorefrontCategory {
  const StorefrontCategory({
    required this.id,
    required this.name,
    this.order = 0,
  });

  final String id;
  final String name;
  /// Display order on the storefront, lowest first.
  final int order;

  factory StorefrontCategory.fromMap(Map<String, dynamic> data, String id) {
    return StorefrontCategory(
      id: id,
      name: data['name'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'order': order};
}

/// Store-wide branding/contact settings for the storefront website, stored
/// in a single `storefront_settings/main` document.
class StorefrontSettings {
  const StorefrontSettings({
    this.storeName = 'Toufic Cell',
    this.whatsappNumber = '96103123456',
    this.currency = Currency.usd,
  });

  final String storeName;
  /// Country code + number, no `+` or spaces (e.g. `96103123456`).
  final String whatsappNumber;
  final Currency currency;

  factory StorefrontSettings.fromMap(Map<String, dynamic> data) {
    return StorefrontSettings(
      storeName: data['storeName'] as String? ?? 'Toufic Cell',
      whatsappNumber: data['whatsappNumber'] as String? ?? '96103123456',
      currency: Currency.fromStorage(data['currency'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'storeName': storeName,
    'whatsappNumber': whatsappNumber,
    'currency': currency.storageValue,
  };
}
