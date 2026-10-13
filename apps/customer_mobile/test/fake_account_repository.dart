import 'package:customer_mobile/features/profile/data/account_repository.dart';

/// In-memory реализация [AccountRepository] для тестов: управляемые задержка,
/// ошибки и состояние бонусов/активного заказа.
final class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    this.bonusBalance = 0,
    this.canDelete = true,
    this.latency = Duration.zero,
  });

  int bonusBalance;
  bool canDelete;

  /// Задержка обоих шагов; для проверки лоадера.
  Duration latency;

  Object? requestError;
  Object? confirmError;

  int requestCount = 0;
  int confirmCount = 0;
  String? lastDeletionToken;

  @override
  Future<DeletionRequest> requestDeletion() async {
    requestCount++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (requestError != null) throw requestError!;
    return DeletionRequest(
      deletionToken: 'deletion-token-$requestCount',
      expiresInSeconds: 300,
      bonusBalance: bonusBalance,
      canDelete: canDelete,
      blockedReason: canDelete ? null : 'ACTIVE_ORDERS_EXIST',
    );
  }

  @override
  Future<DeletionResult> confirmDeletion({required String deletionToken}) async {
    confirmCount++;
    lastDeletionToken = deletionToken;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (confirmError != null) throw confirmError!;
    return DeletionResult(
      deleted: true,
      expiredBonusPoints: bonusBalance,
    );
  }
}
