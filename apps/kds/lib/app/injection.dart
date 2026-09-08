import 'package:get_it/get_it.dart';

import '../core/audio/kitchen_alert_service.dart';
import '../core/config/kds_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/kitchen_session_store.dart';
import '../core/storage/kitchen_token_storage.dart';
import '../features/auth/bloc/kitchen_auth_cubit.dart';
import '../features/auth/data/kitchen_auth_repository.dart';
import '../features/kds/data/fake_kds_orders_repository.dart';
import '../features/kds/data/kds_orders_repository.dart';
import '../features/kds/data/kitchen_events_client.dart';
import '../features/shift/data/cook_shift_repository.dart';
import '../features/shift/data/fake_cook_shift_repository.dart';

final GetIt getIt = GetIt.instance;

bool get _demoMode => KdsConfig.apiBaseUrl.isEmpty;

/// Registers app-level dependencies (ADR-1618 graph).
///
/// Production (`API_BASE_URL` set): terminal PIN auth against
/// `POST /kitchen/auth/pin`, the board on `/kitchen/orders/active` +
/// `/kitchen/stream`, secure-storage token persistence.
/// Demo (`API_BASE_URL` empty): fake auth (PIN `0000`), in-memory board,
/// silent stream — no network at all.
void setupInjection() {
  if (!getIt.isRegistered<KitchenSessionStore>()) {
    getIt.registerLazySingleton<KitchenSessionStore>(KitchenSessionStore.new);
  }

  if (!getIt.isRegistered<KitchenTokenStorage>()) {
    getIt.registerLazySingleton<KitchenTokenStorage>(
      createKitchenTokenStorage,
    );
  }

  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerLazySingleton<ApiClient>(
      () => ApiClient(
        baseUrl: KdsConfig.apiBaseUrl,
        tokenProvider: () => getIt<KitchenSessionStore>().session?.token,
        onUnauthorized: () =>
            getIt<KitchenSessionStore>().onSessionInvalid?.call(),
      ),
    );
  }

  if (!getIt.isRegistered<KitchenAuthRepository>()) {
    getIt.registerLazySingleton<KitchenAuthRepository>(
      () => _demoMode
          ? FakeKitchenAuthRepository()
          : HttpKitchenAuthRepository(getIt<ApiClient>()),
    );
  }

  if (!getIt.isRegistered<KitchenAuthCubit>()) {
    getIt.registerLazySingleton<KitchenAuthCubit>(() {
      final cubit = KitchenAuthCubit(
        repository: getIt<KitchenAuthRepository>(),
        storage: getIt<KitchenTokenStorage>(),
        sessionStore: getIt<KitchenSessionStore>(),
      );
      getIt<KitchenSessionStore>().onSessionInvalid =
          cubit.handleSessionExpired;
      return cubit;
    });
  }

  if (!getIt.isRegistered<KdsOrdersRepository>()) {
    getIt.registerLazySingleton<KdsOrdersRepository>(
      () => _demoMode
          ? FakeKdsOrdersRepository()
          : HttpKdsOrdersRepository(getIt<ApiClient>()),
    );
  }

  if (!getIt.isRegistered<KitchenEventsClient>()) {
    getIt.registerLazySingleton<KitchenEventsClient>(
      () => _demoMode
          ? const FakeKitchenEventsClient()
          : HttpKitchenEventsClient(getIt<ApiClient>()),
    );
  }

  if (!getIt.isRegistered<KitchenAlertService>()) {
    getIt.registerLazySingleton<KitchenAlertService>(
      AudioKitchenAlertService.new,
      dispose: (service) => service.dispose(),
    );
  }

  if (!getIt.isRegistered<CookShiftRepository>()) {
    getIt.registerLazySingleton<CookShiftRepository>(
      () => _demoMode
          ? FakeCookShiftRepository()
          : RemoteCookShiftRepository(getIt<ApiClient>()),
    );
  }
}
