import 'package:equatable/equatable.dart';

final class MenuCategoryRef extends Equatable {
  const MenuCategoryRef({
    required this.id,
    required this.name,
    required this.menuId,
  });
  final String id;
  final String name;
  final String menuId;

  factory MenuCategoryRef.fromJson(Map<String, dynamic> json) =>
      MenuCategoryRef(
        id: json['id'] as String,
        name: json['name'] as String,
        menuId: json['menuId'] as String,
      );

  @override
  List<Object?> get props => [id, name, menuId];
}
