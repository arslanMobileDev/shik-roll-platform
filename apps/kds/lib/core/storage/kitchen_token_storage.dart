import 'package:equatable/equatable.dart';

import 'kitchen_token_storage_stub.dart'
    if (dart.library.io) 'kitchen_token_storage_io.dart'
    if (dart.library.js_interop) 'kitchen_token_storage_web.dart' as impl;

/// Authenticated kitchen-terminal session (ADR-1618 / API-709).
///
/// Shared device identity: the JWT belongs to the terminal, not to a person.
final class KitchenSession extends Equatable {
  const KitchenSession({
    required this.token,
    required this.expiresInSeconds,
    required this.terminalId,
    required this.terminalCode,
    required this.terminalName,
    required this.branchId,
    required this.storedAt,
  });

  final String token;
  final int expiresInSeconds;
  final String terminalId;
  final String terminalCode;
  final String terminalName;
  final String branchId;

  /// When the session was persisted — TTL is checked against this.
  final DateTime storedAt;

  bool isExpiredAt(DateTime now) =>
      now.difference(storedAt).inSeconds >= expiresInSeconds;

  Map<String, dynamic> toJson() => {
    'token': token,
    'expiresInSeconds': expiresInSeconds,
    'terminalId': terminalId,
    'terminalCode': terminalCode,
    'terminalName': terminalName,
    'branchId': branchId,
    'storedAt': storedAt.toIso8601String(),
  };

  factory KitchenSession.fromJson(Map<String, dynamic> json) => KitchenSession(
    token: json['token'] as String? ?? '',
    expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
    terminalId: json['terminalId'] as String? ?? '',
    terminalCode: json['terminalCode'] as String? ?? '',
    terminalName: json['terminalName'] as String? ?? '',
    branchId: json['branchId'] as String? ?? '',
    storedAt:
        DateTime.tryParse(json['storedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  List<Object?> get props => [
    token,
    expiresInSeconds,
    terminalId,
    terminalCode,
    terminalName,
    branchId,
    storedAt,
  ];
}

/// Persists the kitchen-terminal JWT between app launches.
///
/// Platform policy (ADR-1618): native builds use the OS secure enclave via
/// `flutter_secure_storage`; the web build uses **session storage only** —
/// a terminal JWT must never land in persistent browser storage.
abstract interface class KitchenTokenStorage {
  Future<KitchenSession?> read();
  Future<void> write(KitchenSession session);
  Future<void> clear();
}

/// Platform implementation (secure storage on native, session storage on web).
KitchenTokenStorage createKitchenTokenStorage() =>
    impl.createKitchenTokenStorage();
