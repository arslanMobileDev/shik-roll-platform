import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/features/auth/bloc/cook_auth_cubit.dart';
import 'package:kds/features/auth/data/cook_auth_repository.dart';
import 'package:kds/features/auth/view/cook_login_screen.dart';

class Repo implements CookAuthRepository {
  bool fail = false;
  int calls = 0;
  @override
  Future<CookSession> login(String phone, String pin) async {
    calls++;
    if (fail) throw Exception('offline');
    return const CookSession(
      token: 'token',
      shiftId: 'shift',
      id: 'cook',
      name: 'Иван',
    );
  }

  @override
  Future<void> logout(CookSession s) async {}
  @override
  Future<Map<String, dynamic>> stats(CookSession s, String period) async => {};
}

void main() {
  for (final mode in ['success', 'error', 'empty']) {
    testWidgets('cook login $mode', (tester) async {
      final repo = Repo()..fail = mode == 'error';
      final cubit = CookAuthCubit(repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const CookLoginScreen(),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('cook-phone')),
        '89280000000',
      );
      if (mode != 'empty') {
        await tester.enterText(find.byKey(const Key('cook-pin')), '1234');
      }
      await tester.tap(find.byKey(const Key('cook-login')));
      await tester.pumpAndSettle();
      if (mode == 'success') {
        expect(cubit.state.session?.name, 'Иван');
      } else {
        expect(cubit.state.error, isNotNull);
        expect(cubit.state.session, isNull);
      }
      if (mode == 'empty') expect(repo.calls, 0);
    });
  }
}
