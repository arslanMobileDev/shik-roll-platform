import 'package:equatable/equatable.dart';

import 'branch.dart';
import 'courier.dart';

/// Courier session: JWT token + courier profile + active branch.
class CourierSession extends Equatable {
  const CourierSession({
    required this.token,
    required this.courier,
    required this.branch,
    this.phone,
  });

  final String token;
  final Courier courier;
  final Branch branch;
  final String? phone;

  CourierSession copyWith({Branch? branch, String? phone}) => CourierSession(
        token: token,
        courier: courier,
        branch: branch ?? this.branch,
        phone: phone ?? this.phone,
      );

  factory CourierSession.fromJson(Map<String, dynamic> json) => CourierSession(
        token: json['token'] as String,
        courier: Courier.fromJson(json['courier'] as Map<String, dynamic>),
        branch: Branch.fromJson(json['branch'] as Map<String, dynamic>),
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'courier': courier.toJson(),
        'branch': branch.toJson(),
        if (phone != null) 'phone': phone,
      };

  @override
  List<Object?> get props => [token, courier, branch, phone];
}
