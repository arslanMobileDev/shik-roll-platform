import 'kitchen_token_storage.dart';

/// Fallback for platforms with no dedicated implementation.
KitchenTokenStorage createKitchenTokenStorage() =>
    throw UnsupportedError('No KitchenTokenStorage for this platform');
