import 'package:dio/dio.dart';

final class CookSession {
  const CookSession({
    required this.token,
    required this.shiftId,
    required this.id,
    required this.name,
  });
  final String token, shiftId, id, name;
  factory CookSession.fromJson(Map<String, dynamic> json) {
    final cook = json['cook'] as Map<String, dynamic>;
    return CookSession(
      token: json['token'] as String,
      shiftId: json['shiftId'] as String,
      id: cook['id'] as String,
      name: cook['name'] as String,
    );
  }
}

abstract interface class CookAuthRepository {
  Future<CookSession> login(String phone, String pin);
  Future<void> logout(CookSession session);
  Future<Map<String, dynamic>> stats(CookSession session, String period);
}

final class HttpCookAuthRepository implements CookAuthRepository {
  HttpCookAuthRepository({
    required String baseUrl,
    required this.terminalToken,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           );
  final Dio _dio;
  final String? Function() terminalToken;
  @override
  Future<CookSession> login(String phone, String pin) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cooks/auth/pin',
      data: {'phone': phone, 'pin': pin},
      options: Options(headers: {'Authorization': 'Bearer ${terminalToken()}'}),
    );
    return CookSession.fromJson(r.data!);
  }

  @override
  Future<void> logout(CookSession s) async {
    await _dio.post<void>(
      '/cooks/auth/logout',
      options: Options(headers: {'Authorization': 'Bearer ${s.token}'}),
    );
  }

  @override
  Future<Map<String, dynamic>> stats(CookSession s, String period) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/cooks/me/stats',
      queryParameters: {'period': period},
      options: Options(headers: {'Authorization': 'Bearer ${s.token}'}),
    );
    return r.data!;
  }
}
