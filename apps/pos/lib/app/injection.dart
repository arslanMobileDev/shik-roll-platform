import 'package:get_it/get_it.dart';

import '../core/config/pos_config.dart';
import '../core/network/api_client.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/orders/data/fake_orders_repository.dart';
import '../features/orders/data/orders_api_data_source.dart';
import '../features/orders/data/orders_repository.dart';

final GetIt getIt = GetIt.instance;

/// Registers app-level dependencies.
///
/// With `API_BASE_URL` unset the POS runs against [FakeCatalogRepository]
/// (demo catalog) and [FakeOrdersRepository]; otherwise it talks to the
/// Menu & Product API and the Orders API.
void setupInjection() {
  if (getIt.isRegistered<CatalogRepository>()) return;

  getIt.registerLazySingleton<CatalogRepository>(() {
    if (PosConfig.apiBaseUrl.isEmpty) {
      return FakeCatalogRepository();
    }
    return RemoteCatalogRepository(ApiClient(baseUrl: PosConfig.apiBaseUrl));
  });

  getIt.registerLazySingleton<OrdersRepository>(() {
    if (PosConfig.apiBaseUrl.isEmpty) {
      return FakeOrdersRepository();
    }
    return RemoteOrdersRepository(
      OrdersApiDataSource(ApiClient(baseUrl: PosConfig.apiBaseUrl)),
    );
  });
}
