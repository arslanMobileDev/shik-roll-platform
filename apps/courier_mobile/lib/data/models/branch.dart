import 'package:equatable/equatable.dart';

/// SHIK ROLL branch (точка/филиал).
class Branch extends Equatable {
  const Branch({required this.id, required this.name});

  final String id;
  final String name;

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}
