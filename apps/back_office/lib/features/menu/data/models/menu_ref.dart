import 'package:equatable/equatable.dart';

final class MenuRef extends Equatable {
  const MenuRef({required this.id, required this.name, required this.brandId});
  final String id;
  final String name;
  final String brandId;

  factory MenuRef.fromJson(Map<String, dynamic> json) => MenuRef(
    id: json['id'] as String,
    name: json['name'] as String,
    brandId: json['brandId'] as String,
  );

  @override
  List<Object?> get props => [id, name, brandId];
}
