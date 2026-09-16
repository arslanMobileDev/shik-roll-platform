import 'package:intl/date_symbol_data_local.dart';
import 'features/dashboard/data/fake_dashboard_repository.dart';
import 'features/dashboard/data/remote_dashboard_repository.dart';
import 'package:flutter/material.dart';

import 'app/back_office_app.dart';
import 'core/config/api_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/cook_shifts/data/cook_shifts_repository.dart';
import 'features/cook_shifts/data/fake_cook_shifts_repository.dart';
import 'features/cook_shifts/data/remote_cook_shifts_repository.dart';
import 'features/menu/data/back_office_repository.dart';
import 'features/menu/data/fake_back_office_repository.dart';
import 'features/menu/data/remote_back_office_repository.dart';
import 'features/orders/data/fake_orders_repository.dart';
import 'features/orders/data/orders_repository.dart';
import 'features/orders/data/remote_orders_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  // Auth always hits the real backend — the fake variant would defeat the
  // purpose of securing the admin panel with staff tokens.
  final authRepository = AuthRepository();

  // Business repositories flip between fake and remote via
  // --dart-define=USE_FAKE_REPOSITORY=true|false.
  final BackOfficeRepository repository = ApiConfig.useFakeRepository
      ? FakeBackOfficeRepository()
      : RemoteBackOfficeRepository();
  final CookShiftsRepository cookShiftsRepository = ApiConfig.useFakeRepository
      ? FakeCookShiftsRepository()
      : RemoteCookShiftsRepository();
  final OrdersRepository ordersRepository = ApiConfig.useFakeRepository
      ? FakeOrdersRepository()
      : RemoteOrdersRepository();

  runApp(
    BackOfficeApp(
      authRepository: authRepository,
      dashboardRepository: ApiConfig.useFakeRepository
          ? FakeDashboardRepository()
          : RemoteDashboardRepository(),
      repository: repository,
      cookShiftsRepository: cookShiftsRepository,
      ordersRepository: ordersRepository,
    ),
  );
}
