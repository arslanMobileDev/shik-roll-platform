import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

/// A single catalog position.
final class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryName,
    required this.price,
    required this.isHalal,
    required this.isAvailable,
    this.categoryId,
    this.imageUrl,
    this.allergens,
  });

  final String id;
  final String? categoryId;

  /// Category name as the API reports it. Categories are brand data, not a
  /// closed set, so there is no local enum to fall back to.
  final String categoryName;
  final String name;
  final String description;
  final Money price;
  final String? imageUrl;
  final String? allergens;
  final bool isHalal;

  /// false = the item is on the stop-list for the active branch.
  final bool isAvailable;

  MenuItem copyWith({
    String? categoryId,
    String? categoryName,
    String? name,
    String? description,
    Money? price,
    String? imageUrl,
    String? allergens,
    bool clearImageUrl = false,
    bool clearAllergens = false,
    bool? isHalal,
    bool? isAvailable,
  }) {
    return MenuItem(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      allergens: clearAllergens ? null : allergens ?? this.allergens,
      isHalal: isHalal ?? this.isHalal,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// Tolerant decoder: handles backend objects, numbers, and strings
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final dynamic priceRaw = json['price'];
    final Money price = switch (priceRaw) {
      final num rubles => Money.fromRubles(rubles.toDouble()),
      final Map<String, dynamic> map => switch (map['effective'] ?? map['branch'] ?? map['base']) {
          final num r => Money.fromRubles(r.toDouble()),
          _ => Money.zero,
        },
      _ => switch (json['priceMinor']) {
          final int minor => Money(minor),
          _ => Money.zero,
        },
    };

    final stopped = switch (json['stopList']) {
      final Map<String, dynamic> sl => sl['isActive'] as bool?,
      _ => json['isStopped'] as bool?,
    };

    final bool available = switch (json['availability']) {
      final Map<String, dynamic> av => av['isAvailable'] as bool? ?? true,
      _ => json['available'] as bool? ?? !(stopped ?? false),
    };

    final dynamic rawCategory = json['category'];

    return MenuItem(
      id: json['id'] as String,
      categoryId: rawCategory is Map ? rawCategory['id'] as String? : null,
      categoryName: switch (rawCategory) {
        final Map<String, dynamic> map => map['name'] as String? ?? '',
        final String name => name,
        _ => '',
      },
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: price,
      imageUrl: json['imageUrl'] as String?,
      allergens: json['allergens'] as String?,
      isHalal: json['isHalal'] as bool? ?? true,
      isAvailable: available,
    );
  }

  @override
  List<Object?> get props => [
    id,
    categoryId,
    categoryName,
    name,
    description,
    price,
    imageUrl,
    allergens,
    isHalal,
    isAvailable,
  ];
}

/// Payload for creating or editing a catalog position.
///
/// Field names mirror the API (API-706): `categoryId` (UUID) and `basePrice`.
/// Anything else is dropped by the Nest whitelist without an error.
final class MenuItemDraft extends Equatable {
  const MenuItemDraft({
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    this.imageUrl,
    this.allergens,
    this.isHalal = true,
  });

  final String name;
  final String description;
  final String categoryId;
  final Money price;
  final String? imageUrl;
  final String? allergens;

  final bool isHalal;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'categoryId': categoryId,
    'basePrice': price.toJson(),
    'imageUrl': imageUrl,
    'allergens': allergens,
    // ponytail: the API drops this — halal is written through
    // `certificationTagIds`, which needs a certification-tags reference the
    // client does not fetch yet. Kept so the payload shape does not change in
    // a commit that is about the category.
    'isHalal': isHalal,
  };

  @override
  List<Object?> get props => [
    name,
    description,
    categoryId,
    price,
    imageUrl,
    allergens,
    isHalal,
  ];
}
