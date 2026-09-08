import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/courier_session.dart';

/// Persists the non-secret courier profile (courier, branch, phone) in
/// SharedPreferences. The JWT is never written here (ADR-1617): it lives in
/// `flutter_secure_storage` under `courier_access_token_v2`.
///
/// One-time migration: a legacy `courier_session_v1` entry (JWT embedded in
/// JSON) is read exactly once via [extractLegacySession] and then removed;
/// the caller moves the token into secure storage.
class CourierAuthStorage {
  CourierAuthStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _profileKey = 'courier_profile_v2';
  static const String _legacySessionKey = 'courier_session_v1';

  /// Saves the profile part of [session]; the token is dropped on purpose.
  Future<void> saveProfile(CourierSession session) =>
      _prefs.setString(_profileKey, jsonEncode(session.toJson()));

  /// Reads the stored profile and re-attaches [token] from secure storage.
  CourierSession? loadProfile({required String token}) {
    final raw = _prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CourierSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        token: token,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Reads and immediately deletes the legacy v1 session (JWT inside JSON).
  /// Returns null when nothing is stored or the payload is unreadable.
  Future<CourierSession?> extractLegacySession() async {
    final raw = _prefs.getString(_legacySessionKey);
    if (raw == null || raw.isEmpty) return null;
    await _prefs.remove(_legacySessionKey);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final token = json['token'];
      if (token is! String || token.isEmpty) return null;
      return CourierSession.fromJson(json, token: token);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_profileKey);
    await _prefs.remove(_legacySessionKey);
  }
}
