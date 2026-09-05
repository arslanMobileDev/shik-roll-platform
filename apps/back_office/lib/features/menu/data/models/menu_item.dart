import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

/// Menu catalog categories (DB-607).
enum MenuCategory {
  rolls('Роллы'),
  sets('Сеты'),
  fastfood('Фастфуд'),
  burgers('Бургеры'),
  drinks('Напитки');

  const MenuCategory(this.label);

  final String label;

  static MenuCategory fromJson(String value) => MenuCategory.values.firstWhere(
    (c) => c.name == value,
    orElse: () => MenuCategory.rolls,
  );
}

/// A single catalog position.
final class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isHalal,
    required this.isAvailable,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final MenuCategory category;
  final Money price;
  final String? imageUrl;
  final bool isHalal;

  /// false = the item is on the stop-list for the active branch.
  final bool isAvailable;

  MenuItem copyWith({
    String? name,
    String? description,
    MenuCategory? category,
    Money? price,
    String? imageUrl,
    bool? isHalal,
    bool? isAvailable,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isHalal: isHalal ?? this.isHalal,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// Tolerant decoder: accepts `price` (rubles, num) or `priceMinor`
  /// (kopecks, int), and `isAvailable` or inverted `isStopped`.
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final price = switch (json) {
      {'priceMinor': final int minor} => Money(minor),
      {'price': final num rubles} => Money.fromRubles(rubles.toDouble()),
      _ => Money.zero,
    };
    final stopped = json['isStopped'] as bool?;
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: MenuCategory.fromJson(json['category'] as String? ?? ''),
      price: price,
      imageUrl: json['imageUrl'] as String?,
      isHalal: json['isHalal'] as bool? ?? true,
      isAvailable: json['isAvailable'] as bool? ?? !(stopped ?? false),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'category': category.name,
    'price': price.toJson(),
    'imageUrl': imageUrl,
    'isHalal': isHalal,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    category,
    price,
    imageUrl,
    isHalal,
    isAvailable,
  ];
}

/// Payload for creating a new catalog position.
final class MenuItemDraft extends Equatable {
  const MenuItemDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isHalal,
    this.imageUrl,
  });

  final String name;
  final String description;
  final MenuCategory category;
  final Money price;
  final String? imageUrl;
  final bool isHalal;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'category': category.name,
    'price': price.toJson(),
    'imageUrl': imageUrl,
    'isHalal': isHalal,
  };

  @override
  List<Object?> get props => [
    name,
    description,
    category,
    price,
    imageUrl,
    isHalal,
  ];
}
