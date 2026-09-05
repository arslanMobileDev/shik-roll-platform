import 'package:flutter/material.dart';

import 'app/back_office_app.dart';
import 'core/config/api_config.dart';
import 'features/menu/data/back_office_repository.dart';
import 'features/menu/data/fake_back_office_repository.dart';
import 'features/menu/data/remote_back_office_repository.dart';

void main() {
  final BackOfficeRepository repository = ApiConfig.useFakeRepository
      ? FakeBackOfficeRepository()
      : RemoteBackOfficeRepository();
  runApp(BackOfficeApp(repository: repository));
}
