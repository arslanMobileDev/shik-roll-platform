import 'auth_models.dart';
import 'auth_repository.dart';

/// In-memory guest auth for development and widget tests.
///
/// Mirrors the dev backend (`SMS_PROVIDER` unset): any phone is accepted
/// and the fixed code `1234` verifies successfully.
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 300)});

  /// Simulated network latency; pass [Duration.zero] in tests.
  final Duration latency;

  /// Fixed dev code, same as the backend without an SMS provider.
  static const devOtpCode = '1234';

  static const _demoCustomer = GuestCustomer(
    id: 'demo-customer-1',
    phone: '+79991234567',
  );

  @override
  Future<OtpChallenge> sendOtp({required String phone}) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return OtpChallenge(phone: phone, expiresInSeconds: 180);
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (code != devOtpCode) {
      throw const AuthException(
        'Неверный код. Проверьте цифры из SMS.',
        statusCode: 401,
        code: 'OTP_INVALID',
      );
    }
    return const AuthSession(
      accessToken: 'demo-access-token',
      refreshToken: 'demo-refresh-token',
      expiresInSeconds: 2592000,
      customer: _demoCustomer,
    );
  }

  @override
  Future<GuestCustomer> getProfile() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return _demoCustomer;
  }
}
