import 'package:equatable/equatable.dart';

/// Authenticated courier profile.
class Courier extends Equatable {
  const Courier({required this.id, required this.name});

  final String id;
  final String name;

  factory Courier.fromJson(Map<String, dynamic> json) => Courier(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  List<Object?> get props => [id, name];
}
