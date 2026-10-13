import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/network/api_client.dart';
import 'package:customer_mobile/features/auth/data/auth_models.dart';
import 'package:customer_mobile/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> body, String path) =>
    Response<Map<String, dynamic>>(
      data: body,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

DioException _badResponse(String path, int statusCode, {Object? body}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.badResponse,
      response: Response<Object>(
        data: body,
        statusCode: statusCode,
        requestOptions: RequestOptions(path: path),
      ),
    );

void main() {
  setUpAll(() => registerFallbackValue(Options()));

  late _MockDio dio;
  late AuthTokenProvider tokenProvider;
  late RemoteAuthRepository repository;

  setUp(() {
    dio = _MockDio();
    tokenProvider = AuthTokenProvider();
    repository = RemoteAuthRepository(
      ApiClient(baseUrl: '', dio: dio),
      tokenProvider,
    );
  });

  group('RemoteAuthRepository: sendOtp', () {
    test('шлёт POST /auth/otp/send с телефоном в E.164', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/send',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async =>
            _ok(const {'phone': '+79991234567', 'expiresInSeconds': 180}, '/auth/otp/send'),
      );

      final challenge = await repository.sendOtp(phone: '+79991234567');

      expect(challenge.phone, '+79991234567');
      expect(challenge.expiresInSeconds, 180);
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/send',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {'phone': '+79991234567'});
    });
  });

  group('RemoteAuthRepository: verifyOtp', () {
    test('верный код → сессия с токенами и профилем', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(const {
          'accessToken': 'access-jwt',
          'refreshToken': 'refresh-jwt',
          'tokenType': 'Bearer',
          'expiresInSeconds': 2592000,
          'customer': {'id': 'customer-1', 'phone': '+79991234567'},
        }, '/auth/otp/verify'),
      );

      final outcome = await repository.verifyOtp(
        phone: '+79991234567',
        code: '1234',
      );

      expect(outcome, isA<OtpVerified>());
      final session = (outcome as OtpVerified).session;
      expect(session.accessToken, 'access-jwt');
      expect(session.refreshToken, 'refresh-jwt');
      expect(session.customer.id, 'customer-1');
      expect(session.customer.name, isNull);
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {'phone': '+79991234567', 'code': '1234'});
    });

    test('RESTORE_AVAILABLE → предложение восстановления, а не сессия', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(const {
          'status': 'RESTORE_AVAILABLE',
          'restoreToken': 'restore-jwt',
          'expiresInSeconds': 300,
          'deletedAt': '2026-09-13T10:00:00.000Z',
        }, '/auth/otp/verify'),
      );

      final outcome = await repository.verifyOtp(
        phone: '+79991234567',
        code: '1234',
      );

      expect(outcome, isA<AccountRestoreOffered>());
      final offer = (outcome as AccountRestoreOffered).offer;
      expect(offer.restoreToken, 'restore-jwt');
      expect(offer.expiresInSeconds, 300);
      expect(offer.deletedAt, DateTime.utc(2026, 9, 13, 10));
    });

    test('401 OTP_INVALID → понятное сообщение', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _badResponse('/auth/otp/verify', 401, body: {'message': 'OTP_INVALID'}),
      );

      expect(
        repository.verifyOtp(phone: '+79991234567', code: '0000'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'OTP_INVALID')
              .having(
                (e) => e.message,
                'message',
                'Неверный код. Проверьте цифры из SMS.',
              )
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
    });

    test('401 OTP_EXPIRED → просьба запросить новый код', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/verify',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _badResponse('/auth/otp/verify', 401, body: {'message': 'OTP_EXPIRED'}),
      );

      expect(
        repository.verifyOtp(phone: '+79991234567', code: '0000'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Код истёк'),
          ),
        ),
      );
    });

    test('нет соединения → сообщение про интернет', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/otp/send',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/otp/send'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        repository.sendOtp(phone: '+79991234567'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
          ),
        ),
      );
    });
  });

  group('RemoteAuthRepository: restoreAccount', () {
    test('шлёт restoreToken в POST /auth/restore и возвращает сессию', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/restore',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(const {
          'accessToken': 'access-jwt',
          'refreshToken': 'refresh-jwt',
          'expiresInSeconds': 2592000,
          'customer': {'id': 'customer-1', 'phone': '+79991234567'},
        }, '/auth/restore'),
      );

      final session = await repository.restoreAccount(
        restoreToken: 'restore-jwt',
      );

      expect(session.customer.phone, '+79991234567');
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/auth/restore',
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured.single, {'restoreToken': 'restore-jwt'});
    });

    test('409 RESTORE_CONFLICT → номер занят, нужен новый вход', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/auth/restore',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        _badResponse(
          '/auth/restore',
          409,
          body: {'message': 'RESTORE_CONFLICT'},
        ),
      );

      expect(
        repository.restoreAccount(restoreToken: 'restore-jwt'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'RESTORE_CONFLICT')
              .having((e) => e.message, 'message', contains('занят')),
        ),
      );
    });
  });

  group('RemoteAuthRepository: getProfile', () {
    test('GET /auth/me с Bearer-токеном сессии', () async {
      tokenProvider.accessToken = 'access-jwt';
      when(
        () => dio.get<Map<String, dynamic>>(
          '/auth/me',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async =>
            _ok(const {'id': 'customer-1', 'phone': '+79991234567'}, '/auth/me'),
      );

      final profile = await repository.getProfile();

      expect(profile.id, 'customer-1');
      final captured = verify(
        () => dio.get<Map<String, dynamic>>(
          '/auth/me',
          options: captureAny(named: 'options'),
        ),
      ).captured.single as Options;
      expect(captured.headers?['Authorization'], 'Bearer access-jwt');
    });

    test('401 → AuthException.isUnauthorized', () {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/auth/me',
          options: any(named: 'options'),
        ),
      ).thenThrow(_badResponse('/auth/me', 401, body: {'message': 'TOKEN_INVALID'}));

      expect(
        repository.getProfile(),
        throwsA(isA<AuthException>().having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)),
      );
    });
  });
}
