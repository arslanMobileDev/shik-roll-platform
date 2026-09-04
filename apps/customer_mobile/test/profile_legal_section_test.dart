import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/legal/data/legal_constants.dart';
import 'package:customer_mobile/features/legal/view/legal_document_viewer_screen.dart';
import 'package:customer_mobile/features/profile/view/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final _documentsTile = find.byKey(const ValueKey('legal-documents-tile'));
final _menuOffer = find.byKey(const ValueKey('legal-menu-offer'));
final _menuPrivacy = find.byKey(const ValueKey('legal-menu-privacy'));

/// Профиль гостя (без сессии): правовой раздел доступен и анониму.
Future<void> _pumpProfile(WidgetTester tester) async {
  final authBloc = AuthBloc(
    repository: FakeAuthRepository(latency: Duration.zero),
    tokenStorage: InMemoryAuthTokenStorage(),
    tokenProvider: AuthTokenProvider(),
  )..add(const AuthStarted());
  addTearDown(authBloc.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const ProfileScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('пункт «Документы» открывает меню выбора из двух документов', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await tester.tap(_documentsTile);
    await tester.pumpAndSettle();

    expect(_menuOffer, findsOneWidget);
    expect(_menuPrivacy, findsOneWidget);
    expect(find.text('Публичная оферта'), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
  });

  testWidgets('из меню оферта открывается полным текстом с реквизитами', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await tester.tap(_documentsTile);
    await tester.pumpAndSettle();
    await tester.tap(_menuOffer);
    await tester.pumpAndSettle();

    // Полноэкранный просмотр: заголовок и полный текст с реквизитами.
    expect(find.byType(LegalDocumentViewerScreen), findsOneWidget);
    expect(find.text('Публичная оферта'), findsOneWidget);
    expect(
      find.textContaining('ИНН ${LegalConstants.operatorInn}'),
      findsOneWidget,
    );

    // Назад — обратно в профиль.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentViewerScreen), findsNothing);
    expect(_documentsTile, findsOneWidget);
  });

  testWidgets('из меню политика открывается полным текстом (152-ФЗ)', (
    tester,
  ) async {
    await _pumpProfile(tester);

    await tester.tap(_documentsTile);
    await tester.pumpAndSettle();
    await tester.tap(_menuPrivacy);
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentViewerScreen), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.textContaining('152-ФЗ'), findsWidgets);

    // Локализация баз данных докручивается скроллом.
    await tester.scrollUntilVisible(
      find.textContaining('Таймвэб.Облако'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Таймвэб.Облако'), findsOneWidget);
  });
}
