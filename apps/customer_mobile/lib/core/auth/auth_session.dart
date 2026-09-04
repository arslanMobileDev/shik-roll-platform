import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Persisted guest session: JWT tokens from `POST /auth/otp/verify` plus the
/// customer snapshot needed to render the profile offline.
///
/// The auth contract has no profile-update endpoint, so a locally edited
/// [name] is stored here until the backend exposes one.
final class StoredAuthSession extends Equatable {
  const StoredAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.customerId,
    required this.phone,
    this.name,
  });

  factory StoredAuthSession.fromJson(Map<String, dynamic> json) {
    try {
      return StoredAuthSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        customerId: json['customerId'] as String,
        phone: json['phone'] as String,
        name: json['name'] as String?,
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed stored session: $e');
    }
  }

  /// Decodes the record written by [SecureAuthTokenStorage].
  factory StoredAuthSession.decode(String raw) =>
      StoredAuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  final String accessToken;
  final String refreshToken;
  final String customerId;

  /// E.164 (`+7XXXXXXXXXX`).
  final String phone;
  final String? name;

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'customerId': customerId,
    'phone': phone,
    if (name != null) 'name': name,
  };

  StoredAuthSession copyWith({String? name}) => StoredAuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    customerId: customerId,
    phone: phone,
    name: name ?? this.name,
  );

  @override
  List<Object?> get props => [accessToken, refreshToken, customerId, phone, name];
}
