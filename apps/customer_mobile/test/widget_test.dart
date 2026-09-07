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

  Future<void> pumpTracker(WidgetTester tester, UserSettingsCubit cubit) async {
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<UserSettingsCubit>.value(
            value: cubit,
            child: OrderStatusTracker(
              status: 'COOKING',
              orderNumber: '1234',
              remainingMinutes: 25,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('OrderStatusTracker renders steps from status', (tester) async {
    await pumpTracker(tester, UserSettingsCubit(FakeUserSettingsRepository()));

    // Заголовок заказа и активный шаг.
    expect(find.text('#1234'), findsOneWidget);
    expect(find.text('Шеф готовит'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
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
