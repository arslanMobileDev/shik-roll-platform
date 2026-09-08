import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/money.dart';
import '../data/loyalty_models.dart';
import '../data/loyalty_repository.dart';
import '../domain/bonus_math.dart';

/// Lifecycle of a loyalty request (balance and promotions are tracked
/// separately: the feed is public, the balance requires a guest session).
enum LoyaltyStatus { initial, loading, loaded, failure }

/// Loyalty program state (ADR-1614): server-projected balance, cashback rate,
/// a page of the bonus ledger and the active promotions feed.
final class LoyaltyState extends Equatable {
  const LoyaltyState({
    this.status = LoyaltyStatus.initial,
    this.promotionsStatus = LoyaltyStatus.initial,
    this.balance = 0,
    this.cashbackRate = 0,
    this.transactions = const [],
    this.pagination,
    this.promotions = const [],
    this.errorMessage,
  });

  /// Status of `GET /loyalty/balance` (requires auth).
  final LoyaltyStatus status;

  /// Status of `GET /promotions/feed` (public).
  final LoyaltyStatus promotionsStatus;

  /// Current bonus balance (1 point = 1 RUB). Server-projected — the app
  /// never computes it from the ledger.
  final int balance;

  /// Cashback rate in percent (0..100) for the «+X бонусов» previews.
  final double cashbackRate;

  /// Newest-first page of the bonus ledger.
  final List<BonusTransaction> transactions;
  final LoyaltyPagination? pagination;

  /// ACTIVE promotion campaigns for the menu carousel.
  final List<PromotionCampaign> promotions;

  final String? errorMessage;

  /// The balance payload arrived at least once.
  bool get hasBalance => status == LoyaltyStatus.loaded;

  /// Points already accrued for [orderId] (EARN entries of the loaded page).
  int earnedPointsFor(String orderId) => transactions
      .where((t) => t.type == BonusTransactionType.earn && t.orderId == orderId)
      .fold(0, (sum, t) => sum + t.points);

  /// Points applicable to a cart of [subtotal]: the 30% limit capped by the
  /// balance (ADR-1614 `max_bonus_points`). Preview only — the server
  /// re-checks at checkout.
  int maxSpendablePoints(Money subtotal) => maxBonusPoints(subtotal, balance);

  LoyaltyState copyWith({
    LoyaltyStatus? status,
    LoyaltyStatus? promotionsStatus,
    int? balance,
    double? cashbackRate,
    List<BonusTransaction>? transactions,
    LoyaltyPagination? pagination,
    List<PromotionCampaign>? promotions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoyaltyState(
      status: status ?? this.status,
      promotionsStatus: promotionsStatus ?? this.promotionsStatus,
      balance: balance ?? this.balance,
      cashbackRate: cashbackRate ?? this.cashbackRate,
      transactions: transactions ?? this.transactions,
      pagination: pagination ?? this.pagination,
      promotions: promotions ?? this.promotions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    promotionsStatus,
    balance,
    cashbackRate,
    transactions,
    pagination,
    promotions,
    errorMessage,
  ];
}

/// Loads the guest's bonus balance and the public promotions feed
/// (ADR-1614). The balance is personal — load it only for an authenticated
/// guest and [clear] it on sign-out; the feed is public.
class LoyaltyCubit extends Cubit<LoyaltyState> {
  LoyaltyCubit({required this._repository}) : super(const LoyaltyState());

  final LoyaltyRepository _repository;

  /// `GET /promotions/feed`: ACTIVE campaigns of the current brand for the
  /// menu carousel. Failures are non-fatal — the carousel simply hides.
  Future<void> loadPromotions() async {
    emit(state.copyWith(promotionsStatus: LoyaltyStatus.loading));
    try {
      final feed = await _repository.getPromotionFeed();
      emit(
        state.copyWith(
          promotionsStatus: LoyaltyStatus.loaded,
          promotions: feed,
        ),
      );
    } on LoyaltyException {
      emit(state.copyWith(promotionsStatus: LoyaltyStatus.failure));
    }
  }

  /// `GET /loyalty/balance`: balance, cashback rate and a page of the
  /// ledger, newest first.
  Future<void> loadBalance({int page = 1, int pageSize = 20}) async {
    emit(state.copyWith(status: LoyaltyStatus.loading, clearError: true));
    try {
      final result = await _repository.getBalance(
        page: page,
        pageSize: pageSize,
      );
      emit(
        state.copyWith(
          status: LoyaltyStatus.loaded,
          balance: result.balance,
          cashbackRate: result.cashbackRate,
          transactions: result.transactions,
          pagination: result.pagination,
        ),
      );
    } on LoyaltyException catch (e) {
      emit(
        state.copyWith(status: LoyaltyStatus.failure, errorMessage: e.message),
      );
    }
  }

  /// Reloads both payloads (e.g. after checkout or when the tracked order
  /// completes and cashback lands on the ledger).
  Future<void> refresh() async {
    await Future.wait([loadBalance(), loadPromotions()]);
  }

  /// Wipes the personal payload on sign-out; the public feed stays.
  void clear() => emit(
    LoyaltyState(
      promotions: state.promotions,
      promotionsStatus: state.promotionsStatus,
    ),
  );
}
