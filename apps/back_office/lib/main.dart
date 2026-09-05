import 'package:flutter/material.dart';

import 'app/back_office_app.dart';
import 'core/config/api_config.dart';
import 'features/cook_shifts/data/cook_shifts_repository.dart';
import 'features/cook_shifts/data/fake_cook_shifts_repository.dart';
import 'features/cook_shifts/data/remote_cook_shifts_repository.dart';
import 'features/menu/data/back_office_repository.dart';
import 'features/menu/data/fake_back_office_repository.dart';
import 'features/menu/data/remote_back_office_repository.dart';
import 'features/orders/data/fake_orders_repository.dart';
import 'features/orders/data/orders_repository.dart';
import 'features/orders/data/remote_orders_repository.dart';

void main() {
  final BackOfficeRepository repository = ApiConfig.useFakeRepository
      ? FakeBackOfficeRepository()
      : RemoteBackOfficeRepository();
  final CookShiftsRepository cookShiftsRepository =
      ApiConfig.useFakeRepository
      ? FakeCookShiftsRepository()
      : RemoteCookShiftsRepository();
  final OrdersRepository ordersRepository = ApiConfig.useFakeRepository
      ? FakeOrdersRepository()
      : RemoteOrdersRepository();
  runApp(
    BackOfficeApp(
      repository: repository,
      cookShiftsRepository: cookShiftsRepository,
      ordersRepository: ordersRepository,
    ),
  );
}
