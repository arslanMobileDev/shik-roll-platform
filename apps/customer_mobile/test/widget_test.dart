import 'package:customer_mobile/features/orders/domain/order_timeline.dart';
import 'package:customer_mobile/features/orders/presentation/widgets/order_status_tracker.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:customer_mobile/features/profile/domain/delivery_vehicle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

void main() {
  String vehicleAssetName(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image).first);
    final provider = image.image;
    // cacheWidth/cacheHeight оборачивают провайдер в ResizeImage.
    final asset = provider is ResizeImage ? provider.imageProvider : provider;
    return (asset as AssetImage).assetName;
  }

  Future<void> pumpTracker(
    WidgetTester tester,
    UserSettingsCubit cubit, {
    OrderTimelineStatus? status = OrderTimelineStatus.cooking,
    int progressPercent = 40,
    DateTime? estimatedDeliveryAt,
    DateTime? updatedAt,
    bool settle = true,
  }) async {
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<UserSettingsCubit>.value(
            value: cubit,
            child: OrderStatusTracker(
              orderNumber: '1234',
              status: status,
              progressPercent: progressPercent,
              estimatedDeliveryAt: estimatedDeliveryAt,
              updatedAt: updatedAt,
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  double progressValue(WidgetTester tester) =>
      tester
          .widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .value!;

  testWidgets('OrderStatusTracker renders steps from status', (tester) async {
    await pumpTracker(
      tester,
      UserSettingsCubit(FakeUserSettingsRepository()),
      estimatedDeliveryAt: DateTime.now().add(
        const Duration(minutes: 25, seconds: 30),
      ),
    );

    // Заголовок заказа, активный шаг, ETA и процент прогресса.
    expect(find.text('#1234'), findsOneWidget);
    expect(find.text('Шеф готовит'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Шаг 3 из 6'), findsOneWidget);
    expect(find.text('Курьер назначен'), findsOneWidget);
    expect(find.text('Приятного аппетита!'), findsOneWidget);
  });

  testWidgets('показывает расчётное время доставки «Доставка к HH:mm»', (
    tester,
  ) async {
    await pumpTracker(
      tester,
      UserSettingsCubit(FakeUserSettingsRepository()),
      estimatedDeliveryAt: DateTime(2026, 9, 8, 19, 45),
      updatedAt: DateTime(2026, 9, 8, 19, 15),
    );

    expect(find.text('Доставка к'), findsOneWidget);
    expect(find.text('19:45'), findsOneWidget);
    // Время последнего перехода — подпись активного шага.
    expect(find.text('19:15'), findsOneWidget);
  });

  testWidgets('шкала прогресса плавно догоняет новый процент', (tester) async {
    final cubit = UserSettingsCubit(FakeUserSettingsRepository());
    await pumpTracker(tester, cubit, progressPercent: 15);
    expect(progressValue(tester), 0.15);

    // Переход на 75%: на середине анимации значение между старым и новым.
    await pumpTracker(tester, cubit, progressPercent: 75, settle: false);
    await tester.pump(const Duration(milliseconds: 300));
    final mid = progressValue(tester);
    expect(mid, greaterThan(0.15));
    expect(mid, lessThan(0.75));

    await tester.pumpAndSettle();
    expect(progressValue(tester), 0.75);
  });

  testWidgets('отменённый заказ: чип «Отменён», без шкалы прогресса', (
    tester,
  ) async {
    await pumpTracker(
      tester,
      UserSettingsCubit(FakeUserSettingsRepository()),
      status: null,
      progressPercent: 0,
    );

    expect(find.text('Отменён'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Заказ принят'), findsOneWidget);
  });

  testWidgets('до завершения load() трекер безопасно показывает дефолт', (
    tester,
  ) async {
    // Cubit создан, но load() ещё не вызывался.
    await pumpTracker(tester, UserSettingsCubit(FakeUserSettingsRepository()));

    expect(vehicleAssetName(tester), 'assets/icons/delivery_scooter.webp');
  });

  testWidgets('после load() трекер использует транспорт из настроек', (
    tester,
  ) async {
    final cubit = UserSettingsCubit(
      FakeUserSettingsRepository(stored: DeliveryVehicle.redCar),
    );
    await cubit.load();

    await pumpTracker(tester, cubit);

    expect(vehicleAssetName(tester), 'assets/icons/delivery_car.webp');
  });

  testWidgets('трекер перестраивается при смене транспорта в настройках', (
    tester,
  ) async {
    final cubit = UserSettingsCubit(FakeUserSettingsRepository());
    await pumpTracker(tester, cubit);
    expect(vehicleAssetName(tester), 'assets/icons/delivery_scooter.webp');

    await cubit.selectCourierVehicle(DeliveryVehicle.rocket);
    await tester.pump();

    expect(vehicleAssetName(tester), 'assets/icons/delivery_rocket.webp');
  });

  testWidgets('все четыре локальных WebP-ассета транспорта доступны', (
    tester,
  ) async {
    // Регрессия precache: ассеты, которые трекер прогревает, должны
    // существовать в бандле.
    for (final vehicle in DeliveryVehicle.values) {
      expect(vehicle.imageUrl, startsWith('assets/icons/'));
      final bytes = await rootBundle.load(vehicle.imageUrl);
      expect(bytes.lengthInBytes, greaterThan(0));
    }
  });
}
