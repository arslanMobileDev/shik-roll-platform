import 'package:get_it/get_it.dart';

import '../core/config/pos_config.dart';
import '../core/network/api_client.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';

final GetIt getIt = GetIt.instance;

/// Registers app-level dependencies.
///
/// With `API_BASE_URL` unset the POS runs against [FakeCatalogRepository]
/// (demo catalog); otherwise it talks to the Menu & Product API.
void setupInjection() {
  if (getIt.isRegistered<CatalogRepository>()) return;

  getIt.registerLazySingleton<CatalogRepository>(() {
    if (PosConfig.apiBaseUrl.isEmpty) {
      return FakeCatalogRepository();
    }
    return RemoteCatalogRepository(ApiClient(baseUrl: PosConfig.apiBaseUrl));
  });
}
