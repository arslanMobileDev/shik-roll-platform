import 'package:flutter/material.dart';

import 'app/back_office_app.dart';
import 'core/config/api_config.dart';
import 'features/cook_shifts/data/cook_shifts_repository.dart';
import 'features/cook_shifts/data/fake_cook_shifts_repository.dart';
import 'features/cook_shifts/data/remote_cook_shifts_repository.dart';
import 'features/menu/data/back_office_repository.dart';
import 'features/menu/data/fake_back_office_repository.dart';
import 'features/menu/data/remote_back_office_repository.dart';

void main() {
  final BackOfficeRepository repository = ApiConfig.useFakeRepository
      ? FakeBackOfficeRepository()
      : RemoteBackOfficeRepository();
  final CookShiftsRepository cookShiftsRepository =
      ApiConfig.useFakeRepository
      ? FakeCookShiftsRepository()
      : RemoteCookShiftsRepository();
  runApp(
    BackOfficeApp(
      repository: repository,
      cookShiftsRepository: cookShiftsRepository,
    ),
  );
}
