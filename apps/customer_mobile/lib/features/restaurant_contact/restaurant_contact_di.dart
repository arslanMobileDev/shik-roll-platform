import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/auth_token_provider.dart';
import '../../core/network/api_client.dart';
import 'domain/restaurant_contacts.dart';
import 'domain/external_launcher.dart';
import 'data/restaurant_contacts_data.dart';
import 'data/url_external_launcher.dart';
import 'presentation/restaurant_contact_cubit.dart';

void registerRestaurantContacts({
  required GetIt locator,
  required ApiClient client,
  required AuthTokenProvider tokens,
  required SharedPreferences preferences,
  String defaultJson = const String.fromEnvironment(
    'CONTACTS_DEFAULT_JSON',
    // Owner-provided contacts for the configured SHIK ROLL branch only.
    defaultValue:
        '{"branchId":"47ad77ce-acf4-4778-a185-974d3a4a2413",'
        '"phone":"+79283002625",'
        '"address":"г. Минеральные Воды, ул. Бештаугорская, 7а"}',
  ),
}) {
  RestaurantContacts? defaults;
  if (defaultJson.isNotEmpty) {
    // A malformed deployment configuration should be corrected, not hidden.
    defaults = ContactsDto.parse(
      jsonDecode(defaultJson) as Map<String, dynamic>,
    );
  }
  locator.registerLazySingleton<ContactsDataSource>(
    () => RemoteContactsDataSource(client, tokens),
  );
  locator.registerLazySingleton<ContactsCache>(
    () => PreferencesContactsCache(preferences),
  );
  locator.registerLazySingleton<RestaurantContactsRepository>(
    () => CachedRestaurantContactsRepository(
      locator(),
      locator(),
      defaults: defaults,
    ),
  );
  locator.registerLazySingleton<GetRestaurantContactsUseCase>(
    () => GetRestaurantContactsUseCase(locator()),
  );
  locator.registerLazySingleton<ExternalLauncher>(() => UrlExternalLauncher());
  locator.registerFactory<RestaurantContactCubit>(
    () => RestaurantContactCubit(locator()),
  );
}
