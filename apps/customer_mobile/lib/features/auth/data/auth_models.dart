import 'package:equatable/equatable.dart';

import '../../../core/auth/auth_session.dart';

/// `CustomerEntity` from openapi.json (guest profile).
final class GuestCustomer extends Equatable {
  const GuestCustomer({required this.id, required this.phone, this.name});

  factory GuestCustomer.fromJson(Map<String, dynamic> json) {
    try {
      return GuestCustomer(
        id: json['id'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String?,
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed customer payload: $e');
    }
  }

  final String id;

  /// E.164 (`+7XXXXXXXXXX`).
  final String phone;

  /// Display name; null until the guest sets it.
  final String? name;

  GuestCustomer copyWith({String? name}) =>
      GuestCustomer(id: id, phone: phone, name: name ?? this.name);

  @override
  List<Object?> get props => [id, phone, name];
}

/// `SendOtpResponse` from openapi.json: the OTP challenge was sent.
final class OtpChallenge extends Equatable {
  const OtpChallenge({required this.phone, required this.expiresInSeconds});

  factory OtpChallenge.fromJson(Map<String, dynamic> json) {
    try {
      return OtpChallenge(
        phone: json['phone'] as String,
        expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed OTP challenge payload: $e');
    }
  }

  final String phone;
  final int expiresInSeconds;

  @override
  List<Object?> get props => [phone, expiresInSeconds];
}

/// `AuthTokensResponse` from openapi.json: verified session ready to persist.
final class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresInSeconds,
    required this.customer,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    try {
      return AuthSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
        customer: GuestCustomer.fromJson(
          json['customer'] as Map<String, dynamic>,
        ),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed auth tokens payload: $e');
    }
  }

  /// JWT access token (30 days per the auth contract).
  final String accessToken;
  final String refreshToken;
  final int expiresInSeconds;
  final GuestCustomer customer;

  /// Snapshot persisted in the secure storage.
  StoredAuthSession toStored() => StoredAuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    customerId: customer.id,
    phone: customer.phone,
    name: customer.name,
  );

  @override
  List<Object?> get props => [
    accessToken,
    refreshToken,
    expiresInSeconds,
    customer,
  ];
}
