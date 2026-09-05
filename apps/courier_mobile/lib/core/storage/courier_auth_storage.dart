import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/courier_session.dart';

/// Persists the courier session in SharedPreferences.
class CourierAuthStorage {
  CourierAuthStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _sessionKey = 'courier_session_v1';

  Future<void> save(CourierSession session) =>
      _prefs.setString(_sessionKey, jsonEncode(session.toJson()));

  CourierSession? load() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CourierSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> clear() => _prefs.remove(_sessionKey);
}
