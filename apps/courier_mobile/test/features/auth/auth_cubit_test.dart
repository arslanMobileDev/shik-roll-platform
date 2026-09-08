import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:courier_mobile/core/storage/courier_auth_storage.dart';
import 'package:courier_mobile/core/storage/courier_token_storage.dart';
import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/auth/bloc/auth_cubit.dart';
import 'package:courier_mobile/features/auth/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_fakes.dart';

class _MockCourierRepository extends Mock implements CourierRepository {}

Future<({CourierAuthStorage storage, InMemoryCourierTokenStorage tokens})>
freshStorages({Map<String, Object> initialPrefs = const {}}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  return (
    storage: CourierAuthStorage(await SharedPreferences.getInstance()),
    tokens: InMemoryCourierTokenStorage(),
  );
}

void main() {
  group('AuthCubit', () {
    blocTest<AuthCubit, AuthState>(
      'login success stores token in secure storage and profile in prefs',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.login(pin: '1234', phone: '8 (917) 123-45-67'),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>()
            .having((s) => s.session.courier.name, 'courier', 'Мухаммад')
            .having((s) => s.session.branch.id, 'branch', 'branch-center')
            .having((s) => s.session.phone, 'phone', '+79171234567'),
      ],
      verify: (_) async {
        final token = await tokens.read();
        expect(token, isNotNull);
        // Profile persisted without the JWT inside.
        expect(storage.loadProfile(token: token!), isNotNull);
        expect(
          storage.loadProfile(token: token)!.toJson().containsKey('token'),
          isFalse,
        );
      },
    );

    blocTest<AuthCubit, AuthState>(
      'login with invalid PIN emits AuthFailure then AuthUnauthenticated',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.login(pin: '12', phone: '+79171234567'),
      expect: () => [
        const AuthLoading(),
        isA<AuthFailure>(),
        const AuthUnauthenticated(),
      ],
      verify: (_) async {
        expect(await tokens.read(), isNull);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'repository error maps to AuthFailure with message',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
      },
      build: () {
        final repo = _MockCourierRepository();
        when(
          () => repo.loginWithPin(
            pin: any(named: 'pin'),
            phone: any(named: 'phone'),
          ),
        ).thenThrow(const CourierAuthException());
        return AuthCubit(
          repository: repo,
          storage: storage,
          tokenStorage: tokens,
        );
      },
      act: (cubit) => cubit.login(pin: '1234', phone: '+79171234567'),
      expect: () => [
        const AuthLoading(),
        isA<AuthFailure>().having(
          (s) => s.message,
          'message',
          'Неверный PIN или телефон',
        ),
        const AuthUnauthenticated(),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'restore emits AuthAuthenticated for a valid token + stored profile',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
        validJwt = makeTestJwt();
        await tokens.write(validJwt);
        await storage.saveProfile(testSession);
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [
        isA<AuthAuthenticated>()
            .having((s) => s.session.courier.id, 'courierId', 'courier-muhammad')
            .having((s) => s.session.token, 'token', validJwt),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'restore migrates the legacy v1 session exactly once',
      setUp: () async {
        validJwt = makeTestJwt();
        final legacyJson = jsonEncode({
          'token': validJwt,
          'courier': {'id': 'courier-muhammad', 'name': 'Мухаммад'},
          'branch': {'id': 'branch-center', 'name': 'SHIK ROLL — Центр'},
          'phone': '+79170000000',
        });
        final s = await freshStorages(
          initialPrefs: {'courier_session_v1': legacyJson},
        );
        storage = s.storage;
        tokens = s.tokens;
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [
        isA<AuthAuthenticated>().having(
          (s) => s.session.token,
          'token',
          validJwt,
        ),
      ],
      verify: (_) async {
        // Token moved to secure storage; legacy key deleted; profile saved.
        expect(await tokens.read(), validJwt);
        expect(await storage.extractLegacySession(), isNull);
        expect(storage.loadProfile(token: validJwt), isNotNull);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'restore clears an expired token and lands on login',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
        await tokens.write(expiredTestJwt);
        await storage.saveProfile(testSession);
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthUnauthenticated()],
      verify: (_) async {
        expect(await tokens.read(), isNull);
        expect(storage.loadProfile(token: expiredTestJwt), isNull);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'restore emits AuthUnauthenticated when nothing is stored',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'logout clears both storages and emits AuthUnauthenticated',
      setUp: () async {
        final s = await freshStorages();
        storage = s.storage;
        tokens = s.tokens;
        await tokens.write(makeTestJwt());
        await storage.saveProfile(testSession);
      },
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
        tokenStorage: tokens,
      ),
      act: (cubit) => cubit.logout(),
      expect: () => [const AuthUnauthenticated()],
      verify: (_) async {
        expect(await tokens.read(), isNull);
        expect(storage.loadProfile(token: 'any'), isNull);
      },
    );
  });
}

late CourierAuthStorage storage;
late InMemoryCourierTokenStorage tokens;
late String validJwt;
