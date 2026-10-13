import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/core/auth/auth_session.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:customer_mobile/features/profile/data/account_repository.dart';
import 'package:customer_mobile/features/profile/view/delete_account_screen.dart';
import 'package:customer_mobile/features/profile/view/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_account_repository.dart';
import 'fake_user_settings_repository.dart';

final _openTile = find.byKey(const ValueKey('open-delete-screen'));
final _confirmButton = find.byKey(const ValueKey('delete-account-confirm'));
final _finalConfirm = find.byKey(const ValueKey('delete-account-final-confirm'));
final _bonusCard = find.byKey(const ValueKey('delete-account-bonus'));
final _blockedCard = find.byKey(const ValueKey('delete-account-blocked'));

/// Профиль и экран удаления — длинные ListView: расширяем поверхность вместо
/// скролл-костылей в тестах (agent-memory id=44).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Экран открывается push'ем (как из профиля), чтобы поймать результат pop.
Future<List<bool?>> _openScreen(
  WidgetTester tester,
  FakeAccountRepository repository,
) async {
  final results = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-delete-screen'),
              onPressed: () async => results.add(
                await Navigator.of(context).push(
                  DeleteAccountScreen.route(repository),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_openTile);
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('лоадер, затем сводка с суммой сгорающих бонусов', (tester) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository(
      bonusBalance: 120,
      latency: const Duration(milliseconds: 50),
    );

    await tester.pumpWidget(
      MaterialApp(home: DeleteAccountScreen(repository: repository)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Что произойдёт'), findsOneWidget);
    expect(find.text('Сгорят бонусы: 120'), findsOneWidget);
    expect(find.textContaining('30 дней'), findsWidgets);
    expect(_blockedCard, findsNothing);
    expect(tester.widget<FilledButton>(_confirmButton).onPressed, isNotNull);
  });

  testWidgets('нулевой баланс — блока про бонусы нет', (tester) async {
    _useTallSurface(tester);
    await _openScreen(tester, FakeAccountRepository());

    expect(find.text('Что произойдёт'), findsOneWidget);
    expect(_bonusCard, findsNothing);
  });

  testWidgets('активный заказ: кнопка заблокирована с пояснением', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository(canDelete: false);

    await _openScreen(tester, repository);

    expect(_blockedCard, findsOneWidget);
    expect(find.text('Есть незавершённый заказ'), findsOneWidget);
    expect(tester.widget<FilledButton>(_confirmButton).onPressed, isNull);

    // Тап по заблокированной кнопке не доходит до диалога.
    await tester.tap(_confirmButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_finalConfirm, findsNothing);
    expect(repository.confirmCount, 0);
  });

  testWidgets('ошибка шага 1: сообщение и повторный запрос по кнопке', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository()
      ..requestError = const AccountException(
        'Нет соединения с сервером. Проверьте интернет и попробуйте ещё раз.',
      );

    await _openScreen(tester, repository);

    expect(find.textContaining('Нет соединения'), findsOneWidget);
    expect(repository.requestCount, 1);

    repository.requestError = null;
    await tester.tap(find.byKey(const ValueKey('delete-account-retry')));
    await tester.pumpAndSettle();

    expect(repository.requestCount, 2);
    expect(find.text('Что произойдёт'), findsOneWidget);
  });

  testWidgets('отмена диалога не удаляет аккаунт', (tester) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository(bonusBalance: 50);
    final results = await _openScreen(tester, repository);

    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();
    expect(find.text('Удалить аккаунт?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(repository.confirmCount, 0);
    expect(results, isEmpty);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });

  testWidgets('подтверждение удаляет аккаунт и закрывает экран с true', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository(bonusBalance: 50);
    final results = await _openScreen(tester, repository);

    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(_finalConfirm);
    await tester.pumpAndSettle();

    // Токен шага 1 уходит на сервер, экран закрыт с результатом true.
    expect(repository.confirmCount, 1);
    expect(repository.lastDeletionToken, 'deletion-token-1');
    expect(results, [true]);
    expect(find.byType(DeleteAccountScreen), findsNothing);
  });

  testWidgets('409 ACCOUNT_ALREADY_DELETED при подтверждении = успех', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository()
      ..confirmError = const AccountException(
        'Аккаунт уже удалён.',
        statusCode: 409,
        code: 'ACCOUNT_ALREADY_DELETED',
      );
    final results = await _openScreen(tester, repository);

    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(_finalConfirm);
    await tester.pumpAndSettle();

    // Цель достигнута: гость не остаётся на экране удаления с ошибкой.
    expect(results, [true]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ошибка подтверждения: SnackBar, экран остаётся открытым', (
    tester,
  ) async {
    _useTallSurface(tester);
    final repository = FakeAccountRepository()
      ..confirmError = const AccountException(
        'Есть незавершённый заказ. Удаление станет доступно после его завершения.',
        statusCode: 409,
        code: 'ACTIVE_ORDERS_EXIST',
      );
    final results = await _openScreen(tester, repository);

    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(_finalConfirm);
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('незавершённый заказ'), findsOneWidget);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });

  testWidgets('профиль: пункт «Удалить аккаунт» разлогинивает после удаления', (
    tester,
  ) async {
    _useTallSurface(tester);
    final tokenStorage = InMemoryAuthTokenStorage();
    await tokenStorage.save(
      const StoredAuthSession(
        accessToken: 'access-jwt',
        refreshToken: 'refresh-jwt',
        customerId: 'customer-1',
        phone: '+79991234567',
      ),
    );
    final authBloc = AuthBloc(
      repository: FakeAuthRepository(latency: Duration.zero),
      tokenStorage: tokenStorage,
      tokenProvider: AuthTokenProvider(),
    )..add(const AuthStarted());
    addTearDown(authBloc.close);

    final settingsCubit = UserSettingsCubit(FakeUserSettingsRepository());
    addTearDown(settingsCubit.close);

    final repository = FakeAccountRepository(bonusBalance: 30);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<UserSettingsCubit>.value(value: settingsCubit),
            ],
            child: ProfileScreen(accountRepository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вы не вошли в аккаунт'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('delete-account-tile')));
    await tester.pumpAndSettle();
    await tester.tap(_confirmButton);
    await tester.pumpAndSettle();
    await tester.tap(_finalConfirm);
    await tester.pumpAndSettle();

    // Профиль на месте переключился в анонимный вид.
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text('Вы не вошли в аккаунт'), findsOneWidget);
    expect(await tokenStorage.read(), isNull);
  });
}
