import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/network/api_client.dart';
import 'package:customer_mobile/features/profile/data/account_repository.dart';
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
  late RemoteAccountRepository repository;

  setUp(() {
    dio = _MockDio();
    tokenProvider = AuthTokenProvider()..accessToken = 'access-jwt';
    repository = RemoteAccountRepository(
      ApiClient(baseUrl: '', dio: dio),
      tokenProvider,
    );
  });

  group('RemoteAccountRepository: requestDeletion', () {
    test('POST /customers/me/deletion-request с Bearer, разбор ответа', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-request',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(const {
          'deletionToken': 'deletion-jwt',
          'expiresInSeconds': 300,
          'bonusBalance': 120,
          'canDelete': true,
        }, '/customers/me/deletion-request'),
      );

      final request = await repository.requestDeletion();

      expect(request.deletionToken, 'deletion-jwt');
      expect(request.expiresInSeconds, 300);
      expect(request.bonusBalance, 120);
      expect(request.canDelete, isTrue);
      expect(request.blockedReason, isNull);
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-request',
          options: captureAny(named: 'options'),
        ),
      ).captured.single as Options;
      expect(captured.headers?['Authorization'], 'Bearer access-jwt');
    });

    test('canDelete=false с причиной активного заказа', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-request',
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(const {
          'deletionToken': 'deletion-jwt',
          'expiresInSeconds': 300,
          'bonusBalance': 0,
          'canDelete': false,
          'blockedReason': 'ACTIVE_ORDERS_EXIST',
        }, '/customers/me/deletion-request'),
      );

      final request = await repository.requestDeletion();

      expect(request.canDelete, isFalse);
      expect(request.blockedReason, 'ACTIVE_ORDERS_EXIST');
    });

    test('409 ACCOUNT_ALREADY_DELETED → понятное сообщение и признак', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-request',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _badResponse(
          '/customers/me/deletion-request',
          409,
          body: {'message': 'ACCOUNT_ALREADY_DELETED'},
        ),
      );

      expect(
        repository.requestDeletion(),
        throwsA(
          isA<AccountException>()
              .having((e) => e.code, 'code', 'ACCOUNT_ALREADY_DELETED')
              .having((e) => e.isAlreadyDeleted, 'isAlreadyDeleted', isTrue)
              .having((e) => e.message, 'message', 'Аккаунт уже удалён.'),
        ),
      );
    });

    test('401 → isUnauthorized и просьба войти заново', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-request',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _badResponse(
          '/customers/me/deletion-request',
          401,
          body: {'message': 'TOKEN_INVALID'},
        ),
      );

      expect(
        repository.requestDeletion(),
        throwsA(
          isA<AccountException>()
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
              .having((e) => e.message, 'message', contains('Сессия истекла')),
        ),
      );
    });

    test('нет соединения → сообщение про интернет', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-request',
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/customers/me/deletion-request'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        repository.requestDeletion(),
        throwsA(
          isA<AccountException>().having(
            (e) => e.message,
            'message',
            'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
          ),
        ),
      );
    });
  });

  group('RemoteAccountRepository: confirmDeletion', () {
    test('шлёт deletionToken в POST /customers/me/deletion-confirm', () async {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-confirm',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => _ok(const {
          'deleted': true,
          'expiredBonusPoints': 120,
        }, '/customers/me/deletion-confirm'),
      );

      final result = await repository.confirmDeletion(
        deletionToken: 'deletion-jwt',
      );

      expect(result.deleted, isTrue);
      expect(result.expiredBonusPoints, 120);
      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-confirm',
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;
      expect(captured.first, {'deletionToken': 'deletion-jwt'});
      expect(
        (captured.last as Options).headers?['Authorization'],
        'Bearer access-jwt',
      );
    });

    test('409 ACTIVE_ORDERS_EXIST → удаление отложено до конца заказа', () {
      when(
        () => dio.post<Map<String, dynamic>>(
          '/customers/me/deletion-confirm',
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        _badResponse(
          '/customers/me/deletion-confirm',
          409,
          body: {'message': 'ACTIVE_ORDERS_EXIST'},
        ),
      );

      expect(
        repository.confirmDeletion(deletionToken: 'deletion-jwt'),
        throwsA(
          isA<AccountException>()
              .having((e) => e.code, 'code', 'ACTIVE_ORDERS_EXIST')
              .having((e) => e.isAlreadyDeleted, 'isAlreadyDeleted', isFalse)
              .having((e) => e.message, 'message', contains('незавершённый')),
        ),
      );
    });
  });
}
