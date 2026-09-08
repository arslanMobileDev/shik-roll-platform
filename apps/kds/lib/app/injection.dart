import 'package:get_it/get_it.dart';

import '../core/config/kds_config.dart';
import '../core/network/api_client.dart';
import '../features/kds/data/fake_kds_orders_repository.dart';
import '../features/kds/data/kds_orders_repository.dart';
import '../features/shift/data/cook_shift_repository.dart';
import '../features/shift/data/fake_cook_shift_repository.dart';

final GetIt getIt = GetIt.instance;

/// Registers app-level dependencies.
///
/// The KDS talks to the configured backend by default. Supplying an empty
/// `API_BASE_URL` explicitly enables the in-memory demo repositories.
void setupInjection() {
  if (!getIt.isRegistered<KdsOrdersRepository>()) {
    getIt.registerLazySingleton<KdsOrdersRepository>(() {
      if (KdsConfig.apiBaseUrl.isEmpty) {
        return FakeKdsOrdersRepository();
      }
      return RemoteKdsOrdersRepository(
        ApiClient(baseUrl: KdsConfig.apiBaseUrl),
      );
    });
  }

  if (!getIt.isRegistered<CookShiftRepository>()) {
    getIt.registerLazySingleton<CookShiftRepository>(() {
      if (KdsConfig.apiBaseUrl.isEmpty) {
        return FakeCookShiftRepository();
      }
      return RemoteCookShiftRepository(
        ApiClient(baseUrl: KdsConfig.apiBaseUrl),
      );
    });
  }
}
