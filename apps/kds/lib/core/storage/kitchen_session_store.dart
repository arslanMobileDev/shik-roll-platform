import 'kitchen_token_storage.dart';

/// In-memory holder of the active kitchen-terminal session.
///
/// The [ApiClient] Bearer interceptor reads the token from here so HTTP
/// repositories never touch storage; [onSessionInvalid] is wired to the auth
/// cubit's session-expiry handler and fires (single-flight) on the first 401.
final class KitchenSessionStore {
  KitchenSession? session;

  /// Called when the backend rejects the current token with a 401.
  void Function()? onSessionInvalid;
}
