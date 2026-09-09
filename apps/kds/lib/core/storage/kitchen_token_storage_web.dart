import 'dart:convert';

import 'package:web/web.dart' as web;

import 'kitchen_token_storage.dart';

/// Web terminal-token storage: **session storage only** (ADR-1618).
///
/// The JWT survives a tab reload but is gone when the tab closes; it is never
/// written to `localStorage`, IndexedDB or cookies.
KitchenTokenStorage createKitchenTokenStorage() => WebKitchenTokenStorage();

final class WebKitchenTokenStorage implements KitchenTokenStorage {
  static const String _key = 'kitchen.terminal.session.v1';

  @override
  Future<KitchenSession?> read() async {
    final raw = web.window.sessionStorage.getItem(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return KitchenSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(KitchenSession session) async {
    web.window.sessionStorage.setItem(_key, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    web.window.sessionStorage.removeItem(_key);
  }
}
