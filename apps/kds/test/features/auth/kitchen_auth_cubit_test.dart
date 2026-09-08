import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/storage/kitchen_session_store.dart';
import 'package:kds/core/storage/kitchen_token_storage.dart';
import 'package:kds/features/auth/bloc/kitchen_auth_cubit.dart';
import 'package:kds/features/auth/data/kitchen_auth_repository.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  late TestKitchenAuthRepository repository;
  late TestKitchenTokenStorage storage;
  late KitchenSessionStore sessionStore;
  late KitchenAuthCubit cubit;

  setUp(() {
    repository = TestKitchenAuthRepository();
    storage = TestKitchenTokenStorage();
    sessionStore = KitchenSessionStore();
    cubit = KitchenAuthCubit(
      repository: repository,
      storage: storage,
      sessionStore: sessionStore,
    );
  });

  tearDown(() => cubit.close());

  group('restore', () {
    test('no stored session → unauthenticated', () async {
      await cubit.restore();
      expect(cubit.state, isA<KitchenUnauthenticated>());
      expect(sessionStore.session, isNull);
    });

    test('valid stored session → authenticated, store populated', () async {
      final session = buildSession();
      storage.stored = session;

      await cubit.restore();

      expect(cubit.state, isA<KitchenAuthenticated>());
      expect((cubit.state as KitchenAuthenticated).session, session);
      expect(sessionStore.session, session);
    });

    test('expired stored session is discarded locally', () async {
      storage.stored = KitchenSession(
        token: 'old-token',
        expiresInSeconds: 10,
        terminalId: 'terminal-1',
        terminalCode: 'KDS-01',
        terminalName: 'Терминал',
        branchId: 'branch-central',
        storedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await cubit.restore();

      expect(cubit.state, isA<KitchenUnauthenticated>());
      expect(storage.stored, isNull);
      expect(sessionStore.session, isNull);
    });
  });

  group('login', () {
    setUp(() async {
      await cubit.restore();
    });

    test('success persists the session and authenticates', () async {
      final session = buildSession(token: 'jwt-123');
      repository.session = session;

      await cubit.login(terminalCode: 'KDS-01', pin: '1234');

      expect(repository.loginCalls, [('KDS-01', '1234')]);
      expect(cubit.state, isA<KitchenAuthenticated>());
      expect(storage.stored, session);
      expect(sessionStore.session, session);
    });

    test('wrong PIN shows the uniform error and stays logged out', () async {
      repository.loginError = const KitchenAuthException(
        'UNAUTHORIZED',
        'Неверный код терминала или PIN',
      );

      await cubit.login(terminalCode: 'KDS-01', pin: '9999');

      final state = cubit.state as KitchenUnauthenticated;
      expect(state.errorMessage, 'Неверный код терминала или PIN');
      expect(state.busy, isFalse);
      expect(storage.stored, isNull);
      expect(sessionStore.session, isNull);
    });

    test('branch unavailability surfaces its own message', () async {
      repository.loginError = const KitchenAuthException(
        'TERMINAL_BRANCH_UNAVAILABLE',
        'Филиал терминала недоступен',
      );

      await cubit.login(terminalCode: 'KDS-01', pin: '1234');

      expect(
        (cubit.state as KitchenUnauthenticated).errorMessage,
        'Филиал терминала недоступен',
      );
    });

    test('a second login while busy is ignored', () async {
      repository.loginError = const KitchenAuthException(
        'UNAUTHORIZED',
        'Неверный код терминала или PIN',
      );
      final first = cubit.login(terminalCode: 'KDS-01', pin: '1111');
      final second = cubit.login(terminalCode: 'KDS-01', pin: '2222');
      await Future.wait([first, second]);

      expect(repository.loginCalls, hasLength(1));
    });
  });

  group('logout / session expiry', () {
    setUp(() async {
      await cubit.restore();
      await cubit.login(terminalCode: 'KDS-01', pin: '1234');
    });

    test('logout clears storage and the in-memory session', () async {
      await cubit.logout();

      expect(cubit.state, isA<KitchenUnauthenticated>());
      expect(storage.stored, isNull);
      expect(sessionStore.session, isNull);
    });

    test('handleSessionExpired drops the session with an explanation', () async {
      await cubit.handleSessionExpired();

      final state = cubit.state as KitchenUnauthenticated;
      expect(state.errorMessage, contains('истекла'));
      expect(storage.stored, isNull);
      expect(sessionStore.session, isNull);
    });

    test('handleSessionExpired is a no-op when already logged out', () async {
      await cubit.logout();
      final clearsBefore = storage.clearCount;

      await cubit.handleSessionExpired();

      expect(storage.clearCount, clearsBefore);
      expect(cubit.state, isA<KitchenUnauthenticated>());
    });
  });
}
