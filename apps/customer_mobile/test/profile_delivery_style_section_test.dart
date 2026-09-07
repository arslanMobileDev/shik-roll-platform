import 'package:customer_mobile/core/auth/auth_token_provider.dart';
import 'package:customer_mobile/core/auth/auth_token_storage.dart';
import 'package:customer_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:customer_mobile/features/auth/bloc/auth_event.dart';
import 'package:customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:customer_mobile/features/profile/bloc/user_settings_cubit.dart';
import 'package:customer_mobile/features/profile/domain/delivery_vehicle.dart';
import 'package:customer_mobile/features/profile/view/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_user_settings_repository.dart';

final _sectionTile = find.byKey(const ValueKey('delivery-style-tile'));

Future<void> _pumpProfile(
  WidgetTester tester, {
  required FakeUserSettingsRepository settingsRepository,
  bool loadSettings = true,
}) async {
  final authBloc = AuthBloc(
    repository: FakeAuthRepository(latency: Duration.zero),
    tokenStorage: InMemoryAuthTokenStorage(),
    tokenProvider: AuthTokenProvider(),
  )..add(const AuthStarted());
  addTearDown(authBloc.close);

  final settingsCubit = UserSettingsCubit(settingsRepository);
  if (loadSettings) await settingsCubit.load();
  addTearDown(settingsCubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<UserSettingsCubit>.value(value: settingsCubit),
          ],
          child: const ProfileScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late FakeUserSettingsRepository settingsRepository;

  setUp(() => settingsRepository = FakeUserSettingsRepository());

  testWidgets('секция «Мой курьер» показывает сохранённый транспорт', (
    tester,
  ) async {
    settingsRepository = FakeUserSettingsRepository(stored: DeliveryVehicle.redCar);
    await _pumpProfile(tester, settingsRepository: settingsRepository);

    expect(find.text('Мой курьер'), findsOneWidget);
    expect(find.text('Стиль доставки'), findsOneWidget);
    expect(find.text('Красный авто'), findsOneWidget);
  });

  testWidgets('секция доступна и анонимному гостю', (tester) async {
    await _pumpProfile(tester, settingsRepository: settingsRepository);

    // Гость не авторизован (FakeAuthRepository без сессии), но секция видна.
    expect(find.text('Вы не вошли в аккаунт'), findsOneWidget);
    expect(_sectionTile, findsOneWidget);
    expect(find.text('Жёлтый скутер'), findsOneWidget);
  });

  testWidgets('BottomSheet: все варианты, выбранный отмечен чеком', (
    tester,
  ) async {
    await _pumpProfile(tester, settingsRepository: settingsRepository);

    await tester.tap(_sectionTile);
    await tester.pumpAndSettle();

    expect(find.text('Выберите транспорт курьера'), findsOneWidget);
    for (final vehicle in DeliveryVehicle.values) {
      expect(
        find.byKey(ValueKey('vehicle-option-${vehicle.name}')),
        findsOneWidget,
      );
      // Подпись ищем внутри шторки: у выбранного транспорта та же подпись
      // остаётся в подзаголовке секции под шторкой.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(vehicle.label),
        ),
        findsOneWidget,
      );
    }
    // Чек только у текущего (дефолтного) транспорта.
    expect(find.byIcon(Icons.check), findsOneWidget);
    final checkedTile = tester.widget<ListTile>(
      find.byKey(const ValueKey('vehicle-option-yellowScooter')),
    );
    expect(checkedTile.trailing, isNotNull);
    final uncheckedTile = tester.widget<ListTile>(
      find.byKey(const ValueKey('vehicle-option-rocket')),
    );
    expect(uncheckedTile.trailing, isNull);
  });

  testWidgets('выбор транспорта сохраняется, чек и подзаголовок обновляются', (
    tester,
  ) async {
    await _pumpProfile(tester, settingsRepository: settingsRepository);

    await tester.tap(_sectionTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-option-rocket')));
    await tester.pumpAndSettle();

    // Сохранено в настройки.
    expect(settingsRepository.stored, DeliveryVehicle.rocket);
    // Подзаголовок секции обновился.
    expect(find.text('Ракета-доставка'), findsOneWidget);

    // Повторное открытие: чек переехал на ракету.
    await tester.tap(_sectionTile);
    await tester.pumpAndSettle();
    final checkedTile = tester.widget<ListTile>(
      find.byKey(const ValueKey('vehicle-option-rocket')),
    );
    expect(checkedTile.trailing, isNotNull);
  });

  testWidgets('ошибка записи показывает SnackBar и откатывает выбор', (
    tester,
  ) async {
    await _pumpProfile(tester, settingsRepository: settingsRepository);
    settingsRepository.writeError = StateError('disk full');

    await tester.tap(_sectionTile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vehicle-option-rocket')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Не удалось сохранить настройку. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    // Подзаголовок откатился на прежний транспорт.
    expect(find.text('Жёлтый скутер'), findsOneWidget);
    expect(settingsRepository.stored, DeliveryVehicle.yellowScooter);
  });
}
