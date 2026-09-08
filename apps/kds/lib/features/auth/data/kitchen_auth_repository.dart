import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/kitchen_token_storage.dart';

/// Failure of the terminal PIN login with a backend error code (API-709).
final class KitchenAuthException implements Exception {
  const KitchenAuthException(this.code, this.message);

  /// `UNAUTHORIZED` | `TERMINAL_BRANCH_UNAVAILABLE` | `NETWORK`.
  final String code;
  final String message;

  @override
  String toString() => 'KitchenAuthException($code): $message';
}

/// Terminal authentication source (API-709 `POST /kitchen/auth/pin`).
abstract interface class KitchenAuthRepository {
  Future<KitchenSession> login({
    required String terminalCode,
    required String pin,
  });
}

/// Live implementation against the Kitchen API.
final class HttpKitchenAuthRepository implements KitchenAuthRepository {
  HttpKitchenAuthRepository(ApiClient client) : _client = client;

  final ApiClient _client;

  @override
  Future<KitchenSession> login({
    required String terminalCode,
    required String pin,
  }) async {
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/kitchen/auth/pin',
        data: {'terminalCode': terminalCode, 'pin': pin},
      );
      final body = response.data ?? const <String, dynamic>{};
      final terminal =
          (body['terminal'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      return KitchenSession(
        token: body['token'] as String? ?? '',
        expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 0,
        terminalId: terminal['id'] as String? ?? '',
        terminalCode: terminal['code'] as String? ?? terminalCode,
        terminalName: terminal['name'] as String? ?? '',
        branchId: terminal['branchId'] as String? ?? '',
        storedAt: DateTime.now(),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map<String, dynamic> ? data['code'] as String? : null;
      throw KitchenAuthException(
        code ?? 'NETWORK',
        switch ((e.response?.statusCode, code)) {
          (401, 'TERMINAL_BRANCH_UNAVAILABLE') => 'Филиал терминала недоступен',
          (401, _) => 'Неверный код терминала или PIN',
          _ => 'Нет связи с сервером. Проверьте сеть и попробуйте снова.',
        },
      );
    }
  }
}

/// Demo-mode login (API_BASE_URL unset): any terminal code with PIN `0000`
/// opens a local board without a backend.
final class FakeKitchenAuthRepository implements KitchenAuthRepository {
  static const String demoPin = '0000';

  @override
  Future<KitchenSession> login({
    required String terminalCode,
    required String pin,
  }) async {
    if (pin != demoPin) {
      throw const KitchenAuthException(
        'UNAUTHORIZED',
        'Неверный код терминала или PIN (демо-PIN: 0000)',
      );
    }
    return KitchenSession(
      token: 'demo-token',
      expiresInSeconds: 12 * 60 * 60,
      terminalId: 'demo-terminal',
      terminalCode: terminalCode.isEmpty ? 'KDS-DEMO' : terminalCode,
      terminalName: 'Демо-терминал',
      branchId: 'branch-central',
      storedAt: DateTime.now(),
    );
  }
}
