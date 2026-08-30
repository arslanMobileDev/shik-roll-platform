import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';

/// Pagination envelope shared by all Menu & Product API list endpoints.
final class Paged<T> extends Equatable {
  const Paged({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<T> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasNextPage => page < totalPages;

  @override
  List<Object?> get props => [data, page, limit, total, totalPages];
}

/// `MenuEntity` from openapi.json.
final class Menu extends Equatable {
  const Menu({
    required this.id,
    required this.brandId,
    required this.name,
    required this.status,
    required this.categoryCount,
    this.branchId,
  });

  factory Menu.fromJson(Map<String, dynamic> json) => Menu(
    id: json['id'] as String,
    brandId: json['brandId'] as String,
    branchId: json['branchId'] as String?,
    name: json['name'] as String,
    status: json['status'] as String,
    categoryCount: (json['categoryCount'] as num).toInt(),
  );

  final String id;
  final String brandId;
  final String? branchId;
  final String name;
  final String status;
  final int categoryCount;

  bool get isPublished => status == 'PUBLISHED';

  @override
  List<Object?> get props => [id, brandId, branchId, name, status, categoryCount];
}

/// `CategoryEntity` from openapi.json.
final class Category extends Equatable {
  const Category({
    required this.id,
    required this.brandId,
    required this.menuId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.itemCount,
    this.parentId,
    this.description,
    this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    brandId: json['brandId'] as String,
    menuId: json['menuId'] as String,
    parentId: json['parentId'] as String?,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    sortOrder: (json['sortOrder'] as num).toInt(),
    isActive: json['isActive'] as bool,
    itemCount: (json['itemCount'] as num).toInt(),
  );

  final String id;
  final String brandId;
  final String menuId;
  final String? parentId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final int itemCount;

  @override
  List<Object?> get props => [
    id,
    brandId,
    menuId,
    parentId,
    name,
    description,
    imageUrl,
    sortOrder,
    isActive,
    itemCount,
  ];
}

/// `MenuItemCategoryRef` from openapi.json.
final class MenuItemCategoryRef extends Equatable {
  const MenuItemCategoryRef({
    required this.id,
    required this.name,
    required this.menuId,
  });

  factory MenuItemCategoryRef.fromJson(Map<String, dynamic> json) =>
      MenuItemCategoryRef(
        id: json['id'] as String,
        name: json['name'] as String,
        menuId: json['menuId'] as String,
      );

  final String id;
  final String name;
  final String menuId;

  @override
  List<Object?> get props => [id, name, menuId];
}

/// `MenuItemPriceEntity` — prices arrive in rubles and are converted to
/// exact minor units on parse.
final class MenuItemPrice extends Equatable {
  const MenuItemPrice({
    required this.base,
    required this.effective,
    required this.currency,
    this.branch,
  });

  factory MenuItemPrice.fromJson(Map<String, dynamic> json) => MenuItemPrice(
    base: Money.fromRubles(json['base'] as num),
    branch: json['branch'] == null
        ? null
        : Money.fromRubles(json['branch'] as num),
    effective: Money.fromRubles(json['effective'] as num),
    currency: json['currency'] as String,
  );

  final Money base;
  final Money? branch;
  final Money effective;
  final String currency;

  @override
  List<Object?> get props => [base, branch, effective, currency];
}

/// `BranchAvailabilityEntity` from openapi.json.
final class BranchAvailability extends Equatable {
  const BranchAvailability({required this.isAvailable, this.branchId});

  factory BranchAvailability.fromJson(Map<String, dynamic> json) =>
      BranchAvailability(
        branchId: json['branchId'] as String?,
        isAvailable: json['isAvailable'] as bool,
      );

  final String? branchId;
  final bool isAvailable;

  @override
  List<Object?> get props => [branchId, isAvailable];
}

/// `StopListStatusEntity` from openapi.json.
final class StopListStatus extends Equatable {
  const StopListStatus({required this.isActive, this.reason, this.since});

  factory StopListStatus.fromJson(Map<String, dynamic> json) =>
      StopListStatus(
        isActive: json['isActive'] as bool,
        reason: json['reason'] as String?,
        since: json['since'] as String?,
      );

  final bool isActive;
  final String? reason;
  final String? since;

  @override
  List<Object?> get props => [isActive, reason, since];
}

/// `CertificationEntity` from openapi.json.
final class Certification extends Equatable {
  const Certification({
    required this.tagId,
    required this.code,
    required this.name,
    this.certificateNumber,
    this.validUntil,
  });

  factory Certification.fromJson(Map<String, dynamic> json) => Certification(
    tagId: json['tagId'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    certificateNumber: json['certificateNumber'] as String?,
    validUntil: json['validUntil'] as String?,
  );

  final String tagId;
  final String code;
  final String name;
  final String? certificateNumber;
  final String? validUntil;

  @override
  List<Object?> get props => [tagId, code, name, certificateNumber, validUntil];
}

/// `ModifierItemEntity` from openapi.json.
final class ModifierItem extends Equatable {
  const ModifierItem({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.sortOrder,
    this.calories,
  });

  factory ModifierItem.fromJson(Map<String, dynamic> json) => ModifierItem(
    id: json['id'] as String,
    name: json['name'] as String,
    price: Money.fromRubles(json['price'] as num),
    currency: json['currency'] as String,
    calories: (json['calories'] as num?)?.toInt(),
    sortOrder: (json['sortOrder'] as num).toInt(),
  );

  final String id;
  final String name;
  final Money price;
  final String currency;
  final int? calories;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, price, currency, calories, sortOrder];
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

/// Lifecycle status of a menu item (`status` field, DB-607 v1.2.0).
enum MenuItemStatus { draft, published, hidden, archived }

/// `MenuItemEntity` from openapi.json.
final class MenuItem extends Equatable {
  const MenuItem({
    required this.id,
    required this.brandId,
    required this.menuId,
    required this.sku,
    required this.name,
    required this.slug,
    required this.category,
    required this.status,
    required this.sortOrder,
    required this.isPopular,
    required this.isNew,
    required this.isFeatured,
    required this.isHalal,
    required this.available,
    required this.price,
    required this.availability,
    required this.stopList,
    required this.certifications,
    required this.modifierGroups,
    this.description,
    this.weight,
    this.calories,
    this.preparationTime,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as String,
    brandId: json['brandId'] as String,
    menuId: json['menuId'] as String,
    sku: json['sku'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    description: json['description'] as String?,
    category: MenuItemCategoryRef.fromJson(
      json['category'] as Map<String, dynamic>,
    ),
    weight: (json['weight'] as num?)?.toInt(),
    calories: (json['calories'] as num?)?.toInt(),
    preparationTime: (json['preparationTime'] as num?)?.toInt(),
    status: switch (json['status'] as String) {
      'PUBLISHED' => MenuItemStatus.published,
      'HIDDEN' => MenuItemStatus.hidden,
      'ARCHIVED' => MenuItemStatus.archived,
      _ => MenuItemStatus.draft,
    },
    sortOrder: (json['sortOrder'] as num).toInt(),
    isPopular: json['isPopular'] as bool,
    isNew: json['isNew'] as bool,
    isFeatured: json['isFeatured'] as bool,
    isHalal: json['isHalal'] as bool,
    available: json['available'] as bool,
    price: MenuItemPrice.fromJson(json['price'] as Map<String, dynamic>),
    availability: BranchAvailability.fromJson(
      json['availability'] as Map<String, dynamic>,
    ),
    stopList: StopListStatus.fromJson(
      json['stopList'] as Map<String, dynamic>,
    ),
    certifications: [
      for (final c in json['certifications'] as List<dynamic>)
        Certification.fromJson(c as Map<String, dynamic>),
    ],
    modifierGroups: [
      for (final g in json['modifierGroups'] as List<dynamic>)
        ModifierGroup.fromJson(g as Map<String, dynamic>),
    ],
  );

  final String id;
  final String brandId;
  final String menuId;
  final String sku;
  final String name;
  final String slug;
  final String? description;
  final MenuItemCategoryRef category;
  final int? weight;
  final int? calories;
  final int? preparationTime;
  final MenuItemStatus status;
  final int sortOrder;
  final bool isPopular;
  final bool isNew;
  final bool isFeatured;
  final bool isHalal;

  /// Sellable in the requested branch context: PUBLISHED, branch-available
  /// and not stop-listed (per the API contract).
  final bool available;
  final MenuItemPrice price;
  final BranchAvailability availability;
  final StopListStatus stopList;
  final List<Certification> certifications;
  final List<ModifierGroup> modifierGroups;

  bool get isStopListed => stopList.isActive;
  bool get isBranchAvailable => availability.isAvailable;

  @override
  List<Object?> get props => [
    id,
    brandId,
    menuId,
    sku,
    name,
    slug,
    description,
    category,
    weight,
    calories,
    preparationTime,
    status,
    sortOrder,
    isPopular,
    isNew,
    isFeatured,
    isHalal,
    available,
    price,
    availability,
    stopList,
    certifications,
    modifierGroups,
  ];
}
