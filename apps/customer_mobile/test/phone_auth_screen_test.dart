import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_state.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/auth/view/auth_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _phoneField = find.byKey(const ValueKey('phone-field'));
final _sendButton = find.byKey(const ValueKey('send-code-button'));
final _otpField = find.byKey(const ValueKey('otp-field'));
final _verifyButton = find.byKey(const ValueKey('verify-code-button'));
final _resendButton = find.byKey(const ValueKey('resend-code-button'));
final _changePhoneButton = find.byKey(const ValueKey('change-phone-button'));

class _Harness extends StatelessWidget {
  const _Harness({required this.authBloc, required this.onResult});

  final AuthBloc authBloc;
  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const ValueKey('open-auth'),
              onPressed: () async {
                final result = await showAuthFlowSheet(context);
                onResult(result);
              },
              child: const Text('Войти'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the modal auth sheet over the harness and returns the bloc.
Future<AuthBloc> _pumpSheet(
  WidgetTester tester, {
  ValueChanged<bool>? onResult,
}) async {
  final authBloc = AuthBloc(
    repository: FakeAuthRepository(latency: Duration.zero),
    tokenStorage: InMemoryAuthTokenStorage(),
    tokenProvider: AuthTokenProvider(),
  );
  await tester.pumpWidget(
    _Harness(authBloc: authBloc, onResult: onResult ?? (_) {}),
  );
  await tester.tap(find.byKey(const ValueKey('open-auth')));
  await tester.pumpAndSettle();
  return authBloc;
}

Future<void> _requestCode(WidgetTester tester) async {
  await tester.enterText(_phoneField, '9991234567');
  await tester.pump();
  await tester.tap(_sendButton);
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('шаг телефона: маска +7, кнопка активна при полном номере, '
      'есть ссылки на оферту и политику', (tester) async {
    await _pumpSheet(tester);

    expect(find.text('Вход по номеру телефона'), findsOneWidget);
    // Префикс «+7 » живёт в декорации поля, а не в отдельном Text.
    expect(
      tester.widget<TextField>(_phoneField).decoration?.prefixText,
      '+7 ',
    );
    // Ссылки на документы собраны одним Text.rich.
    final legalText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(legalText, contains('Публичную оферту'));
    expect(legalText, contains('Политику обработки персональных данных'));
    // Кнопка заблокирована, пока номер не введён полностью.
    expect(tester.widget<FilledButton>(_sendButton).onPressed, isNull);

    await tester.enterText(_phoneField, '9991234');
    await tester.pump();
    expect(tester.widget<FilledButton>(_sendButton).onPressed, isNull);

    await tester.enterText(_phoneField, '9991234567');
    await tester.pump();
    expect(
      tester.widget<TextField>(_phoneField).controller?.text,
      '(999) 123-45-67',
    );
    expect(tester.widget<FilledButton>(_sendButton).onPressed, isNotNull);

    // Закрываем шторку, чтобы не оставлять открытым маршрут.
    await tester.tap(find.text('Войти'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('полный вход: телефон → код → шторка закрывается с true', (
    tester,
  ) async {
    bool? result;
    final authBloc = await _pumpSheet(tester, onResult: (r) => result = r);

    await _requestCode(tester);
    expect(_otpField, findsOneWidget);
    expect(find.text('Отправили на +79991234567'), findsOneWidget);

    // Автосабмит на четвёртой цифре.
    await tester.enterText(_otpField, '1234');
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(authBloc.state.status, AuthStatus.authenticated);
    expect(result, isTrue);
    expect(_otpField, findsNothing);
  });

  testWidgets('неверный код: ошибка видна, шторка остаётся открытой', (
    tester,
  ) async {
    final authBloc = await _pumpSheet(tester);
    await _requestCode(tester);

    await tester.enterText(_otpField, '0000');
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Неверный код. Проверьте цифры из SMS.'), findsOneWidget);
    expect(authBloc.state.status, AuthStatus.otpSent);
    expect(_otpField, findsOneWidget);

    // Кнопка «Подтвердить» отправляет код повторно (без автосабмита).
    await tester.enterText(_otpField, '12');
    await tester.pump();
    expect(tester.widget<FilledButton>(_verifyButton).onPressed, isNull);

    // Свайп назад на шаг телефона.
    await tester.tap(_changePhoneButton);
    await tester.pump();
    await tester.pump();
    expect(_phoneField, findsOneWidget);
  });

  testWidgets('таймер повторной отправки: 60 секунд, затем кнопка активна', (
    tester,
  ) async {
    await _pumpSheet(tester);
    await _requestCode(tester);

    expect(find.text('Отправить код повторно через 1:00'), findsOneWidget);
    expect(_resendButton, findsNothing);

    // Через секунду таймер тикает.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Отправить код повторно через 0:59'), findsOneWidget);

    // Ждём окончания таймера (ограниченные pump, таймер периодический).
    await tester.pump(const Duration(seconds: 61));
    expect(_resendButton, findsOneWidget);

    await tester.tap(_resendButton);
    await tester.pump();
    await tester.pump();
    // Таймер перезапустился после повторной отправки.
    expect(find.text('Отправить код повторно через 1:00'), findsOneWidget);

    // Возврат на шаг телефона гасит таймер вместе с виджетом.
    await tester.tap(_changePhoneButton);
    await tester.pump();
    await tester.pump();
    expect(_phoneField, findsOneWidget);
  });
}
