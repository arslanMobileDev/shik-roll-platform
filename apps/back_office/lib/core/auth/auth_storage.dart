import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage for the staff JWT and the signed-in actor's profile.
///
/// The JWT is stored in [FlutterSecureStorage] — on Web this uses WebCrypto
/// (AES-GCM with a key held in IndexedDB), so the token is not readable as
/// plain text in localStorage. On mobile it uses Keychain / EncryptedSharedPrefs.
/// The token TTL (12h) is enforced by the backend.
///
/// The non-sensitive profile (id, name, role, brandId) is kept in
/// [SharedPreferences] because it is only displayed in the shell header;
/// compromising it would not give API access.
class AuthStorage {
  AuthStorage._();

  static const _tokenKey = 'staff.token';
  static const _staffIdKey = 'staff.id';
  static const _staffNameKey = 'staff.name';
  static const _staffRoleKey = 'staff.role';
  static const _staffBrandIdKey = 'staff.brandId';

  static const _secure = FlutterSecureStorage();

  /// Load the stored access token, or null when not signed in.
  ///
  /// Migration: if the token was previously saved in [SharedPreferences]
  /// (legacy versions), it is moved to secure storage and removed from
  /// the legacy store on first read.
  static Future<String?> getToken() async {
    final secureToken = await _secure.read(key: _tokenKey);
    if (secureToken != null) return secureToken;

    // Legacy fallback: pre-migration token in SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null) {
      await _secure.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
      return legacyToken;
    }
    return null;
  }

  /// Persist a successful login.
  static Future<void> saveSession({
    required String token,
    required String id,
    required String name,
    required String role,
    required String brandId,
  }) async {
    await _secure.write(key: _tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_staffIdKey, id);
    await prefs.setString(_staffNameKey, name);
    await prefs.setString(_staffRoleKey, role);
    await prefs.setString(_staffBrandIdKey, brandId);
    // Ensure no stale legacy token remains after a successful login.
    await prefs.remove(_tokenKey);
  }

  /// Read the cached staff profile (for UI display); null when not signed in.
  static Future<StaffProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_staffIdKey);
    final name = prefs.getString(_staffNameKey);
    final role = prefs.getString(_staffRoleKey);
    final brandId = prefs.getString(_staffBrandIdKey);
    if (id == null || name == null || role == null || brandId == null) {
      return null;
    }
    return StaffProfile(id: id, name: name, role: role, brandId: brandId);
  }

  /// Drop the session — used by logout and on any 401 from the backend.
  static Future<void> clear() async {
    await _secure.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_staffIdKey);
    await prefs.remove(_staffNameKey);
    await prefs.remove(_staffRoleKey);
    await prefs.remove(_staffBrandIdKey);
  }
}

/// Cached staff identity, shown in the shell header and used for audit.
class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.brandId,
  });

  final String id;
  final String name;
  final String role;
  final String brandId;
}
