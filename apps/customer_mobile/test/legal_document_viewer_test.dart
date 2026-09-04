import 'package:customer_mobile/features/legal/data/legal_constants.dart';
import 'package:customer_mobile/features/legal/data/legal_document.dart';
import 'package:customer_mobile/features/legal/view/legal_document_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _sheetClose = find.byKey(const ValueKey('legal-sheet-close'));

/// Скролл внутри шторки/экрана документа, а не фоновой страницы.
Future<void> _scrollDocumentUntil(
  WidgetTester tester,
  Finder target,
) {
  return tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  testWidgets('экран оферты: разделы, реквизиты, ЮKassa и 54-ФЗ', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentViewerScreen(document: LegalDocument.offer),
      ),
    );

    // Заголовок AppBar и вводный раздел видны сразу.
    expect(find.text('Публичная оферта'), findsOneWidget);
    expect(
      find.textContaining(LegalConstants.operatorName),
      findsOneWidget,
    );
    expect(
      find.textContaining('ИНН ${LegalConstants.operatorInn}'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ОГРНИП ${LegalConstants.operatorOgrnip}'),
      findsOneWidget,
    );
    expect(find.textContaining(LegalConstants.concept), findsOneWidget);

    // Дальние разделы докручиваются скроллом.
    await _scrollDocumentUntil(tester, find.textContaining('ЮKassa'));
    expect(find.text('3. Цена и порядок оплаты'), findsOneWidget);

    await _scrollDocumentUntil(tester, find.textContaining('Атол Сигма'));
    expect(find.text('4. Кассовые чеки (54-ФЗ)'), findsOneWidget);

    await _scrollDocumentUntil(
      tester,
      find.textContaining('Постановление Правительства'),
    );
    expect(
      find.textContaining(LegalConstants.supportEmail),
      findsWidgets,
    );
  });

  testWidgets('экран политики: 152-ФЗ, локализация в Таймвэб, неразглашение', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentViewerScreen(document: LegalDocument.privacy),
      ),
    );

    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.textContaining('152-ФЗ'), findsWidgets);
    expect(
      find.textContaining(LegalConstants.operatorName),
      findsOneWidget,
    );

    await _scrollDocumentUntil(
      tester,
      find.textContaining('Таймвэб.Облако'),
    );
    expect(find.text('3. Хранение и локализация данных'), findsOneWidget);

    await _scrollDocumentUntil(
      tester,
      find.text('4. Передача третьим лицам и неразглашение'),
    );
    expect(find.textContaining('не передаёт персональные данные'), findsOneWidget);
  });

  testWidgets('экран закрывается кнопкой назад', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                LegalDocumentViewerScreen.route(LegalDocument.offer),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentViewerScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentViewerScreen), findsNothing);
  });

  testWidgets('модалка: скролл длинного текста и закрытие кнопкой', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showLegalDocumentSheet(context, LegalDocument.privacy),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Шторка с заголовком и кнопкой закрытия поверх страницы.
    expect(_sheetClose, findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);

    // Контент шторки скроллится до последнего раздела.
    await _scrollDocumentUntil(tester, find.text('6. Контакты Оператора'));
    expect(
      find.textContaining(LegalConstants.supportEmail),
      findsWidgets,
    );

    // Заголовок не уехал вместе со скроллом контента.
    expect(_sheetClose, findsOneWidget);

    await tester.tap(_sheetClose);
    await tester.pumpAndSettle();
    expect(_sheetClose, findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
