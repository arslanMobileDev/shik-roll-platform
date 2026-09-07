import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_mobile/features/orders/presentation/widgets/order_status_tracker.dart';

void main() {
  String vehicleAssetName(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image).first);
    final provider = image.image;
    // cacheWidth/cacheHeight оборачивают провайдер в ResizeImage.
    final asset = provider is ResizeImage ? provider.imageProvider : provider;
    return (asset as AssetImage).assetName;
  }

  testWidgets('OrderStatusTracker renders steps and switches vehicle',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderStatusTracker(
            status: 'COOKING',
            orderNumber: '1234',
            remainingMinutes: 25,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Заголовок заказа и активный шаг.
    expect(find.text('#1234'), findsOneWidget);
    expect(find.text('Шеф готовит'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);

    // По умолчанию выбран жёлтый скутер (локальный ассет).
    expect(vehicleAssetName(tester), 'assets/icons/delivery_scooter.webp');

    // Открываем выбор транспорта и переключаемся на красный авто.
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('Выберите транспорт курьера'), findsOneWidget);

    await tester.tap(find.text('Красный авто'));
    await tester.pumpAndSettle();
    expect(vehicleAssetName(tester), 'assets/icons/delivery_car.webp');
  });
}
