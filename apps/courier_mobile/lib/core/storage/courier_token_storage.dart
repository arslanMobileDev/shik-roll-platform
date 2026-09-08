import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Courier JWT storage contract (ADR-1617). The access token lives only in
/// platform secure storage (Keychain / EncryptedSharedPreferences) — never in
/// SharedPreferences, logs, analytics or crash breadcrumbs.
abstract interface class CourierTokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Secure-storage implementation under the versioned key
/// `courier_access_token_v2`.
class SecureCourierTokenStorage implements CourierTokenStorage {
  const SecureCourierTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String tokenKey = 'courier_access_token_v2';

  @override
  Future<String?> read() => _storage.read(key: tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: tokenKey, value: token);

  @override
  Future<void> clear() => _storage.delete(key: tokenKey);
}

/// In-memory implementation for unit/widget tests.
class InMemoryCourierTokenStorage implements CourierTokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
