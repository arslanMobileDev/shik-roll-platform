import 'package:bloc_test/bloc_test.dart';
import 'package:customer_mobile/core/auth/auth_session.dart';
import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/bloc/auth_state.dart';
import 'package:customer_mobile/features/auth/data/auth_models.dart';
import 'package:customer_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _phone = '+79991234567';

const _challenge = OtpChallenge(phone: _phone, expiresInSeconds: 180);

const _customer = GuestCustomer(id: 'customer-1', phone: _phone);

const _session = AuthSession(
  accessToken: 'access-jwt',
  refreshToken: 'refresh-jwt',
  expiresInSeconds: 2592000,
  customer: _customer,
);

const _stored = StoredAuthSession(
  accessToken: 'stored-access',
  refreshToken: 'stored-refresh',
  customerId: 'customer-1',
  phone: _phone,
  name: 'Арслан',
);

void main() {
  late _MockAuthRepository repository;
  late InMemoryAuthTokenStorage storage;
  late AuthTokenProvider tokenProvider;

  setUp(() {
    repository = _MockAuthRepository();
    storage = InMemoryAuthTokenStorage();
    tokenProvider = AuthTokenProvider();
  });

  AuthBloc buildBloc() => AuthBloc(
    repository: repository,
    tokenStorage: storage,
    tokenProvider: tokenProvider,
  );

  group('AuthBloc: восстановление сессии', () {
    blocTest<AuthBloc, AuthState>(
      'без сохранённой сессии → unauthenticated',
      build: buildBloc,
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [
        predicate<AuthState>(
          (s) => s.status == AuthStatus.unauthenticated && !s.isLoading,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'сохранённая сессия → authenticated, токен доступен репозиториям',
      build: buildBloc,
      setUp: () async {
        await storage.save(_stored);
        when(() => repository.getProfile()).thenAnswer(
          (_) async => const GuestCustomer(
            id: 'customer-1',
            phone: _phone,
            name: 'Арслан (сервер)',
          ),
        );
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [
        // Сначала снапшот из хранилища.
        predicate<AuthState>(
          (s) =>
              s.status == AuthStatus.authenticated &&
              s.customer?.name == 'Арслан' &&
              s.customer?.phone == _phone,
        ),
        // Затем свежий профиль с сервера (его имя приоритетнее).
        predicate<AuthState>(
          (s) =>
              s.status == AuthStatus.authenticated &&
              s.customer?.name == 'Арслан (сервер)',
        ),
      ],
      verify: (_) {
        expect(tokenProvider.accessToken, 'stored-access');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'токен отклонён сервером (401) → сессия очищена',
      build: buildBloc,
      setUp: () async {
        await storage.save(_stored);
        when(() => repository.getProfile()).thenThrow(
          const AuthException('Сессия истекла', statusCode: 401),
        );
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [
        predicate<AuthState>((s) => s.status == AuthStatus.authenticated),
        predicate<AuthState>((s) => s.status == AuthStatus.unauthenticated),
      ],
      verify: (_) async {
        expect(tokenProvider.accessToken, isNull);
        expect(await storage.read(), isNull);
      },
    );
  });

  group('AuthBloc: отправка кода', () {
    blocTest<AuthBloc, AuthState>(
      'успешная отправка → otpSent с телефоном и временем жизни кода',
      build: buildBloc,
      setUp: () => when(
        () => repository.sendOtp(phone: _phone),
      ).thenAnswer((_) async => _challenge),
      act: (bloc) => bloc.add(const AuthOtpSendRequested(phone: _phone)),
      expect: () => [
        predicate<AuthState>(
          (s) => s.isLoading && s.status == AuthStatus.unauthenticated,
        ),
        predicate<AuthState>(
          (s) =>
              s.status == AuthStatus.otpSent &&
              s.phone == _phone &&
              s.otpExpiresInSeconds == 180 &&
              !s.isLoading,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'ошибка сети → unauthenticated с сообщением',
      build: buildBloc,
      setUp: () => when(() => repository.sendOtp(phone: _phone)).thenThrow(
        const AuthException(
          'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
        ),
      ),
      act: (bloc) => bloc.add(const AuthOtpSendRequested(phone: _phone)),
      expect: () => [
        predicate<AuthState>((s) => s.isLoading),
        predicate<AuthState>(
          (s) =>
              s.status == AuthStatus.unauthenticated &&
              s.errorMessage != null &&
              !s.isLoading,
        ),
      ],
    );
  });

  group('AuthBloc: подтверждение кода', () {
    blocTest<AuthBloc, AuthState>(
      'верный код → authenticated, токены сохранены в хранилище',
      build: buildBloc,
      setUp: () => when(
        () => repository.verifyOtp(phone: _phone, code: '1234'),
      ).thenAnswer((_) async => _session),
      seed: () => const AuthState(
        status: AuthStatus.otpSent,
        phone: _phone,
        otpExpiresInSeconds: 180,
      ),
      act: (bloc) => bloc.add(const AuthOtpVerifyRequested(code: '1234')),
      expect: () => [
        predicate<AuthState>((s) => s.isLoading),
        predicate<AuthState>(
          (s) =>
              s.status == AuthStatus.authenticated &&
              s.customer?.id == 'customer-1' &&
              !s.isLoading,
        ),
      ],
      verify: (_) async {
        expect(tokenProvider.accessToken, 'access-jwt');
        final storedSession = await storage.read();
        expect(storedSession?.refreshToken, 'refresh-jwt');
        expect(storedSession?.customerId, 'customer-1');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'неверный код → остаёмся на шаге ввода с сообщением',
      build: buildBloc,
      setUp: () => when(
        () => repository.verifyOtp(phone: _phone, code: '0000'),
      ).thenThrow(
        const AuthException(
          'Неверный код. Проверьте цифры из SMS.',
          statusCode: 401,
          code: 'OTP_INVALID',
        ),
      ),
      seed: () => const AuthState(
        status: AuthStatus.otpSent,
        phone: _phone,
        otpExpiresInSeconds: 180,
      ),
      act: (bloc) => bloc.add(const AuthOtpVerifyRequested(code: '0000')),
      expect: () => [
        predicate<AuthState>((s) => s.isLoading),
        predicate<AuthState>(
          (s) =>
              s.status == AuthStatus.otpSent &&
              s.errorMessage == 'Неверный код. Проверьте цифры из SMS.' &&
              !s.isLoading,
        ),
      ],
      verify: (_) async {
        expect(tokenProvider.accessToken, isNull);
        expect(await storage.read(), isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'повторная отправка кода → новый challenge',
      build: buildBloc,
      setUp: () => when(
        () => repository.sendOtp(phone: _phone),
      ).thenAnswer((_) async => _challenge),
      seed: () => const AuthState(
        status: AuthStatus.otpSent,
        phone: _phone,
        otpExpiresInSeconds: 180,
      ),
      act: (bloc) => bloc.add(const AuthOtpResendRequested()),
      expect: () => [
        predicate<AuthState>((s) => s.isLoading),
        predicate<AuthState>(
          (s) => s.status == AuthStatus.otpSent && s.phone == _phone,
        ),
      ],
      verify: (_) =>
          verify(() => repository.sendOtp(phone: _phone)).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      '«Изменить номер» → назад на шаг телефона',
      build: buildBloc,
      seed: () => const AuthState(
        status: AuthStatus.otpSent,
        phone: _phone,
        otpExpiresInSeconds: 180,
      ),
      act: (bloc) => bloc.add(const AuthOtpCancelled()),
      expect: () => [
        predicate<AuthState>(
          (s) => s.status == AuthStatus.unauthenticated && s.phone == _phone,
        ),
      ],
    );
  });

  group('AuthBloc: профиль и выход', () {
    blocTest<AuthBloc, AuthState>(
      'сохранение имени обновляет состояние и хранилище',
      build: buildBloc,
      setUp: () => storage.save(_stored),
      seed: () => const AuthState(
        status: AuthStatus.authenticated,
        phone: _phone,
        customer: _customer,
      ),
      act: (bloc) => bloc.add(const AuthNameSubmitted(name: '  Арслан  ')),
      expect: () => [
        predicate<AuthState>((s) => s.customer?.name == 'Арслан'),
      ],
      verify: (_) async {
        expect((await storage.read())?.name, 'Арслан');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'выход очищает токены и состояние',
      build: buildBloc,
      setUp: () {
        storage.save(_stored);
        tokenProvider.accessToken = 'access-jwt';
      },
      seed: () => const AuthState(
        status: AuthStatus.authenticated,
        phone: _phone,
        customer: _customer,
      ),
      act: (bloc) => bloc.add(const AuthLoggedOut()),
      expect: () => [
        predicate<AuthState>(
          (s) => s.status == AuthStatus.unauthenticated && s.customer == null,
        ),
      ],
      verify: (_) async {
        expect(tokenProvider.accessToken, isNull);
        expect(await storage.read(), isNull);
      },
    );
  });
}
