import 'package:get_it/get_it.dart';

import '../core/config/kds_config.dart';
import '../core/network/api_client.dart';
import '../features/kds/data/fake_kds_orders_repository.dart';
import '../features/kds/data/kds_orders_repository.dart';

final GetIt getIt = GetIt.instance;

/// Registers app-level dependencies.
///
/// With `API_BASE_URL` unset the KDS runs against [FakeKdsOrdersRepository]
/// (demo order stream); otherwise it talks to the Orders API (API-702).
void setupInjection() {
  if (getIt.isRegistered<KdsOrdersRepository>()) return;

  getIt.registerLazySingleton<KdsOrdersRepository>(() {
    if (KdsConfig.apiBaseUrl.isEmpty) {
      return FakeKdsOrdersRepository();
    }
    return RemoteKdsOrdersRepository(ApiClient(baseUrl: KdsConfig.apiBaseUrl));
  });
}
