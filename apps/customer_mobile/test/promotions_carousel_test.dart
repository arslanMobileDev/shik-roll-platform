import 'package:customer_mobile/features/loyalty/bloc/loyalty_cubit.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_models.dart';
import 'package:customer_mobile/features/loyalty/data/loyalty_repository.dart';
import 'package:customer_mobile/features/loyalty/view/promotions_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

PromotionCampaign _campaign(String id, String title) => PromotionCampaign(
  id: id,
  title: title,
  description: 'Описание $id',
  bannerUrl: '',
  startsAt: DateTime(2026, 9, 1),
  endsAt: DateTime(2026, 9, 30),
);

Future<void> _pumpCarousel(WidgetTester tester, LoyaltyCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider<LoyaltyCubit>.value(
          value: cubit,
          child: const PromotionsCarousel(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('карусель показывает баннеры активных акций (ADR-1614)', (
    tester,
  ) async {
    final cubit = LoyaltyCubit(
      repository: FakeLoyaltyRepository(
        latency: Duration.zero,
        promotions: [
          _campaign('promo-1', 'Кешбэк 10% в сентябре'),
          _campaign('promo-2', 'Сет дня −20%'),
          _campaign('promo-3', 'Ролл в подарок'),
          _campaign('promo-4', 'Комбо недели'),
          _campaign('promo-5', 'Счастливые часы'),
        ],
      ),
    );
    await cubit.loadPromotions();
    await _pumpCarousel(tester, cubit);

    expect(find.byKey(const ValueKey('promotions-carousel')), findsOneWidget);
    expect(find.text('Кешбэк 10% в сентябре'), findsOneWidget);
    // Дальний баннер за пределами вьюпорта и cacheExtent — не собран.
    expect(find.text('Счастливые часы'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Счастливые часы'),
      240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('promotions-carousel')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Счастливые часы'), findsOneWidget);
  });

  testWidgets('пустая лента: карусель не занимает место в каталоге', (
    tester,
  ) async {
    final cubit = LoyaltyCubit(
      repository: FakeLoyaltyRepository(
        latency: Duration.zero,
        promotions: const [],
      ),
    );
    await cubit.loadPromotions();
    await _pumpCarousel(tester, cubit);

    expect(find.byKey(const ValueKey('promotions-carousel')), findsNothing);
  });

  testWidgets('до загрузки ленты карусель скрыта', (tester) async {
    final cubit = LoyaltyCubit(
      repository: FakeLoyaltyRepository(latency: Duration.zero),
    );
    await _pumpCarousel(tester, cubit);

    expect(find.byKey(const ValueKey('promotions-carousel')), findsNothing);
  });
}
