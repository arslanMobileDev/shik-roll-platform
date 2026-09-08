import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/storage/kitchen_session_store.dart';
import 'package:kds/features/auth/bloc/kitchen_auth_cubit.dart';
import 'package:kds/features/auth/data/kitchen_auth_repository.dart';
import 'package:kds/features/auth/view/kitchen_login_screen.dart';

import '../../helpers/test_fixtures.dart';

void main() {
  Future<(KitchenAuthCubit, TestKitchenAuthRepository)> pumpLogin(
    WidgetTester tester,
  ) async {
    final repository = TestKitchenAuthRepository();
    final cubit = KitchenAuthCubit(
      repository: repository,
      storage: TestKitchenTokenStorage(),
      sessionStore: KitchenSessionStore(),
    );
    await cubit.restore();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const KitchenLoginScreen(),
        ),
      ),
    );
    return (cubit, repository);
  }

  testWidgets('валидный код + 4-значный PIN вызывают login', (tester) async {
    final (cubit, repository) = await pumpLogin(tester);
    addTearDown(cubit.close);

    await tester.enterText(find.byKey(const Key('kitchen-login-code')), ' KDS-01 ');
    await tester.enterText(find.byKey(const Key('kitchen-login-pin')), '1234');
    await tester.tap(find.byKey(const Key('kitchen-login-submit')));
    await tester.pumpAndSettle();

    // Код терминала нормализуется (trim) перед отправкой.
    expect(repository.loginCalls, [('KDS-01', '1234')]);
    expect(cubit.state, isA<KitchenAuthenticated>());
  });

  testWidgets('пустой код: ошибка валидации, login не вызывается', (
    tester,
  ) async {
    final (cubit, repository) = await pumpLogin(tester);
    addTearDown(cubit.close);

    await tester.enterText(find.byKey(const Key('kitchen-login-pin')), '1234');
    await tester.tap(find.byKey(const Key('kitchen-login-submit')));
    await tester.pump();

    expect(find.text('Введите код терминала'), findsOneWidget);
    expect(repository.loginCalls, isEmpty);
  });

  testWidgets('PIN не из 4 цифр: ошибка валидации', (tester) async {
    final (cubit, repository) = await pumpLogin(tester);
    addTearDown(cubit.close);

    await tester.enterText(find.byKey(const Key('kitchen-login-code')), 'KDS-01');
    await tester.enterText(find.byKey(const Key('kitchen-login-pin')), '12');
    await tester.tap(find.byKey(const Key('kitchen-login-submit')));
    await tester.pump();

    expect(find.text('PIN — ровно 4 цифры'), findsOneWidget);
    expect(repository.loginCalls, isEmpty);
  });

  testWidgets('буквы в PIN отсекаются форматтером', (tester) async {
    final (cubit, _) = await pumpLogin(tester);
    addTearDown(cubit.close);

    await tester.enterText(find.byKey(const Key('kitchen-login-pin')), '1a2b');
    await tester.pump();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('kitchen-login-pin')),
    );
    expect(field.controller?.text, '12');
  });

  testWidgets('ошибка сервера показывается в форме', (tester) async {
    final (cubit, repository) = await pumpLogin(tester);
    addTearDown(cubit.close);
    repository.loginError = const KitchenAuthException(
      'UNAUTHORIZED',
      'Неверный код терминала или PIN',
    );

    await tester.enterText(find.byKey(const Key('kitchen-login-code')), 'KDS-01');
    await tester.enterText(find.byKey(const Key('kitchen-login-pin')), '9999');
    await tester.tap(find.byKey(const Key('kitchen-login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kitchen-login-error')), findsOneWidget);
    expect(find.text('Неверный код терминала или PIN'), findsOneWidget);
  });
}
