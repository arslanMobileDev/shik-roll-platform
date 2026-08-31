import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';

/// Pagination envelope shared by Menu & Product API list endpoints.
final class Paged<T> extends Equatable {
  const Paged({
    required this.data,
    required this.page,
    required this.hasNextPage,
  });

  final List<T> data;
  final int page;
  final bool hasNextPage;

  @override
  List<Object?> get props => [data, page, hasNextPage];
}

/// `CategoryEntity` from openapi.json.
final class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    sortOrder: (json['sortOrder'] as num).toInt(),
    isActive: json['isActive'] as bool,
  );

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, sortOrder, isActive];
}

/// `MenuItemCategoryRef` from openapi.json.
final class MenuItemCategoryRef extends Equatable {
  const MenuItemCategoryRef({required this.id, required this.name});

  factory MenuItemCategoryRef.fromJson(Map<String, dynamic> json) =>
      MenuItemCategoryRef(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// `ModifierItemEntity` from openapi.json.
final class ModifierItem extends Equatable {
  const ModifierItem({
    required this.id,
    required this.name,
    required this.price,
    required this.sortOrder,
  });

  factory ModifierItem.fromJson(Map<String, dynamic> json) => ModifierItem(
    id: json['id'] as String,
    name: json['name'] as String,
    price: Money.fromRubles(json['price'] as num),
    sortOrder: (json['sortOrder'] as num).toInt(),
  );

  final String id;
  final String name;
  final Money price;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, price, sortOrder];
}

enum ModifierSelectionType { single, multiple }

/// `ModifierGroupEntity` from openapi.json.
final class ModifierGroup extends Equatable {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.minSelected,
    required this.isRequired,
    required this.sortOrder,
    required this.items,
    this.maxSelected,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) => ModifierGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    selectionType: json['selectionType'] == 'SINGLE'
        ? ModifierSelectionType.single
        : ModifierSelectionType.multiple,
    minSelected: (json['minSelected'] as num).toInt(),
    maxSelected: (json['maxSelected'] as num?)?.toInt(),
    isRequired: json['isRequired'] as bool,
    sortOrder: (json['sortOrder'] as num).toInt(),
    items: [
      for (final item in json['items'] as List<dynamic>)
        ModifierItem.fromJson(item as Map<String, dynamic>),
    ],
  );

  final String id;
  final String name;
  final ModifierSelectionType selectionType;
  final int minSelected;
  final int? maxSelected;
  final bool isRequired;
  final int sortOrder;
  final List<ModifierItem> items;

  bool get isSingleChoice => selectionType == ModifierSelectionType.single;

  @override
  List<Object?> get props => [
    id,
    name,
    selectionType,
    minSelected,
    maxSelected,
    isRequired,
    sortOrder,
    items,
  ];
}

/// `MenuItemEntity` from openapi.json (trimmed to the fields the guest
/// showcase consumes).
final class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.sortOrder,
    required this.isPopular,
    required this.isNew,
    required this.isHalal,
    required this.available,
    required this.modifierGroups,
    this.description,
    this.weight,
    this.calories,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as String,
    sku: json['sku'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    category: MenuItemCategoryRef.fromJson(
      json['category'] as Map<String, dynamic>,
    ),
    weight: (json['weight'] as num?)?.toInt(),
    calories: (json['calories'] as num?)?.toInt(),
    price: Money.fromRubles(
      (json['price'] as Map<String, dynamic>)['effective'] as num,
    ),
    sortOrder: (json['sortOrder'] as num).toInt(),
    isPopular: json['isPopular'] as bool,
    isNew: json['isNew'] as bool,
    isHalal: json['isHalal'] as bool,
    available: json['available'] as bool,
    modifierGroups: [
      for (final g in json['modifierGroups'] as List<dynamic>)
        ModifierGroup.fromJson(g as Map<String, dynamic>),
    ],
  );

  final String id;
  final String sku;
  final String name;
  final String? description;
  final MenuItemCategoryRef category;
  final int? weight;
  final int? calories;
  final Money price;
  final int sortOrder;
  final bool isPopular;
  final bool isNew;
  final bool isHalal;
  final bool available;
  final List<ModifierGroup> modifierGroups;

  bool get hasModifiers => modifierGroups.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    sku,
    name,
    description,
    category,
    weight,
    calories,
    price,
    sortOrder,
    isPopular,
    isNew,
    isHalal,
    available,
    modifierGroups,
  ];
}
