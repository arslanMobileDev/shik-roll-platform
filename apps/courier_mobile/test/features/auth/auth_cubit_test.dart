import 'package:bloc_test/bloc_test.dart';
import 'package:courier_mobile/core/storage/courier_auth_storage.dart';
import 'package:courier_mobile/data/repositories/courier_repository.dart';
import 'package:courier_mobile/data/repositories/fake_courier_repository.dart';
import 'package:courier_mobile/features/auth/bloc/auth_cubit.dart';
import 'package:courier_mobile/features/auth/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_fakes.dart';

class _MockCourierRepository extends Mock implements CourierRepository {}

Future<CourierAuthStorage> freshStorage() async {
  SharedPreferences.setMockInitialValues({});
  return CourierAuthStorage(await SharedPreferences.getInstance());
}

void main() {
  late CourierAuthStorage storage;

  setUp(() async {
    storage = await freshStorage();
  });

  group('AuthCubit', () {
    blocTest<AuthCubit, AuthState>(
      'login success saves session and emits AuthAuthenticated',
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
      ),
      act: (cubit) => cubit.login(
        pin: '1234',
        phone: '+79171234567',
        branch: testBranch,
      ),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>()
            .having((s) => s.session.courier.name, 'courier', 'Мухаммад')
            .having((s) => s.session.branch.id, 'branch', 'branch-center'),
      ],
      verify: (_) {
        expect(storage.load()?.token, isNotNull);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'login with invalid PIN emits AuthFailure then AuthUnauthenticated',
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
      ),
      act: (cubit) => cubit.login(
        pin: '12',
        phone: '+79171234567',
        branch: testBranch,
      ),
      expect: () => [
        const AuthLoading(),
        isA<AuthFailure>(),
        const AuthUnauthenticated(),
      ],
      verify: (_) {
        expect(storage.load(), isNull);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'repository error maps to AuthFailure with message',
      build: () {
        final repo = _MockCourierRepository();
        when(
          () => repo.loginWithPin(
            pin: any(named: 'pin'),
            phone: any(named: 'phone'),
          ),
        ).thenThrow(const CourierAuthException());
        return AuthCubit(repository: repo, storage: storage);
      },
      act: (cubit) => cubit.login(
        pin: '1234',
        phone: '+79171234567',
        branch: testBranch,
      ),
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
      'restore emits AuthAuthenticated when session persisted',
      setUp: () async => storage.save(testSession),
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [
        isA<AuthAuthenticated>().having(
          (s) => s.session.courier.id,
          'courierId',
          'courier-muhammad',
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'restore emits AuthUnauthenticated when no session stored',
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
      ),
      act: (cubit) => cubit.restore(),
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'logout clears storage and emits AuthUnauthenticated',
      setUp: () async => storage.save(testSession),
      build: () => AuthCubit(
        repository: FakeCourierRepository(),
        storage: storage,
      ),
      act: (cubit) => cubit.logout(),
      expect: () => [const AuthUnauthenticated()],
      verify: (_) {
        expect(storage.load(), isNull);
      },
    );
  });
}
