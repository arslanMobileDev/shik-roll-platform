import 'package:equatable/equatable.dart';

final class MenuCategoryRef extends Equatable {
  const MenuCategoryRef({
    required this.id,
    required this.name,
    required this.menuId,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String menuId;
  final String? description;

  /// Position inside the menu; the create dialog appends via `max + 1`.
  final int sortOrder;

  /// Inactive categories stay in the back-office (to be reactivated) but are
  /// filtered out of the public catalog by the API.
  final bool isActive;

  factory MenuCategoryRef.fromJson(Map<String, dynamic> json) =>
      MenuCategoryRef(
        id: json['id'] as String,
        name: json['name'] as String,
        menuId: json['menuId'] as String,
        description: json['description'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    menuId,
    description,
    sortOrder,
    isActive,
  ];
}

/// Editable category fields; `menuId` and `sortOrder` are positional and stay
/// out of the draft, so a rename can never move a category between menus.
final class CategoryDraft extends Equatable {
  const CategoryDraft({
    required this.name,
    this.description,
    this.isActive = true,
  });

  final String name;
  final String? description;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'isActive': isActive,
  };

  @override
  List<Object?> get props => [name, description, isActive];
}
