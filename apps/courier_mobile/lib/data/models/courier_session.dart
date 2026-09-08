import 'package:equatable/equatable.dart';

import 'branch.dart';
import 'courier.dart';

/// Courier session: JWT token + courier profile + active branch.
///
/// ADR-1617: the token is a runtime-only field. `toJson` never serializes it
/// and `fromJson` receives it separately (from secure storage), so the
/// SharedPreferences profile never contains the JWT.
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

  factory CourierSession.fromJson(
    Map<String, dynamic> json, {
    String token = '',
  }) =>
      CourierSession(
        token: token,
        courier: Courier.fromJson(json['courier'] as Map<String, dynamic>),
        branch: Branch.fromJson(json['branch'] as Map<String, dynamic>),
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'courier': courier.toJson(),
        'branch': branch.toJson(),
        if (phone != null) 'phone': phone,
      };

  @override
  List<Object?> get props => [token, courier, branch, phone];
}
