import 'package:dio/dio.dart';

import '../../../core/auth/auth_storage.dart';
import '../../../core/network/api_client.dart';

/// Result of a successful POST /staff/auth/pin.
class LoginResult {
  const LoginResult({required this.profile});

  final StaffProfile profile;
}

/// Thrown when the backend rejects the login attempt.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Staff authentication against the SHIK backend.
///
/// The login endpoint is the only one called without a token; everything
/// else in the back office uses the session stored by [AuthStorage].
class AuthRepository {
  AuthRepository({ApiClient? client}) : _dio = (client ?? ApiClient()).dio;

  final Dio _dio;

  /// POST /staff/auth/pin — issue a scoped staff JWT for phone + PIN.
  Future<LoginResult> login({
    required String phone,
    required String pin,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/staff/auth/pin',
        data: {'phone': phone, 'pin': pin},
      );

      final data = response.data ?? const <String, dynamic>{};
      final token = data['token'] as String?;
      final staff = data['staff'] as Map<String, dynamic>?;
      if (token == null || staff == null) {
        throw const AuthException('Некорректный ответ сервера');
      }

      final profile = StaffProfile(
        id: staff['id'] as String,
        name: staff['name'] as String,
        role: staff['role'] as String,
        brandId: staff['brandId'] as String,
      );

      await AuthStorage.saveSession(
        token: token,
        id: profile.id,
        name: profile.name,
        role: profile.role,
        brandId: profile.brandId,
      );

      return LoginResult(profile: profile);
    } on DioException catch (e) {
      throw AuthException(_describe(e));
    }
  }

  /// Drop the local session (does not call the backend, JWT is stateless).
  Future<void> logout() => AuthStorage.clear();

  String _describe(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return 'Неверный номер телефона или PIN';
    if (status == 429) return 'Слишком много попыток. Попробуйте позже.';
    if (status != null) return 'Ошибка сервера ($status)';
    return 'Не удалось подключиться к серверу';
  }
}
