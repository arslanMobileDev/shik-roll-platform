import 'package:equatable/equatable.dart';

/// API contracts of the loyalty bounded context (ADR-1614). Wire format is
/// snake_case; bonus points are JSON integers (1 point = 1 RUB), money would
/// be decimal strings. The balance is a server-side projection — the app
/// never computes or mutates it locally.

/// `BonusTransactionType` from the ADR-1614 ledger contract.
enum BonusTransactionType {
  earn,
  spend,
  expire,
  refund;

  /// Wire value (`EARN`, `SPEND`, `EXPIRE`, `REFUND`).
  String get wireName => switch (this) {
    BonusTransactionType.earn => 'EARN',
    BonusTransactionType.spend => 'SPEND',
    BonusTransactionType.expire => 'EXPIRE',
    BonusTransactionType.refund => 'REFUND',
  };

  static BonusTransactionType fromWire(String value) => switch (value) {
    'EARN' => BonusTransactionType.earn,
    'SPEND' => BonusTransactionType.spend,
    'EXPIRE' => BonusTransactionType.expire,
    'REFUND' => BonusTransactionType.refund,
    _ => throw FormatException('Unknown bonus transaction type: $value'),
  };
}

/// One immutable ledger row of `GET /loyalty/balance` (ADR-1614).
///
/// [points] is signed: EARN/REFUND are positive, SPEND/EXPIRE negative.
final class BonusTransaction extends Equatable {
  const BonusTransaction({
    required this.id,
    required this.type,
    required this.points,
    required this.balanceAfter,
    required this.createdAt,
    this.orderId,
    this.expiresAt,
  });

  factory BonusTransaction.fromJson(Map<String, dynamic> json) {
    try {
      return BonusTransaction(
        id: json['id'] as String,
        type: BonusTransactionType.fromWire(json['type'] as String),
        points: (json['points'] as num).toInt(),
        balanceAfter: (json['balance_after'] as num).toInt(),
        orderId: json['order_id'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        expiresAt: json['expires_at'] is String
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed bonus transaction payload: $e');
    }
  }

  final String id;
  final BonusTransactionType type;

  /// Signed points: EARN/REFUND > 0; SPEND/EXPIRE < 0.
  final int points;

  /// Balance projection immediately after this entry.
  final int balanceAfter;

  /// Order the entry is bound to (`spend:{orderId}` / `earn:{orderId}`).
  final String? orderId;

  final DateTime createdAt;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [
    id,
    type,
    points,
    balanceAfter,
    orderId,
    createdAt,
    expiresAt,
  ];
}

/// Pagination envelope of `GET /loyalty/balance`.
final class LoyaltyPagination extends Equatable {
  const LoyaltyPagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory LoyaltyPagination.fromJson(Map<String, dynamic> json) {
    try {
      return LoyaltyPagination(
        page: (json['page'] as num).toInt(),
        pageSize: (json['page_size'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        totalPages: (json['total_pages'] as num).toInt(),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed loyalty pagination payload: $e');
    }
  }

  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasNextPage => page < totalPages;

  @override
  List<Object?> get props => [page, pageSize, total, totalPages];
}

/// `LoyaltyBalanceResponseDto` (ADR-1614): current balance, cashback rate and
/// a page of the ledger, newest first (`created_at DESC, id DESC`).
final class LoyaltyBalance extends Equatable {
  const LoyaltyBalance({
    required this.balance,
    required this.cashbackRate,
    required this.transactions,
    required this.pagination,
  });

  factory LoyaltyBalance.fromJson(Map<String, dynamic> json) {
    try {
      return LoyaltyBalance(
        balance: (json['balance'] as num).toInt(),
        cashbackRate: (json['cashback_rate'] as num).toDouble(),
        transactions: [
          for (final item
              in (json['transactions'] as List<dynamic>? ?? const []))
            BonusTransaction.fromJson(item as Map<String, dynamic>),
        ],
        pagination: LoyaltyPagination.fromJson(
          json['pagination'] as Map<String, dynamic>,
        ),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed loyalty balance payload: $e');
    }
  }

  static const empty = LoyaltyBalance(
    balance: 0,
    cashbackRate: 0,
    transactions: [],
    pagination: LoyaltyPagination(
      page: 1,
      pageSize: 20,
      total: 0,
      totalPages: 0,
    ),
  );

  /// Current bonus balance (1 point = 1 RUB). Never computed client-side.
  final int balance;

  /// Cashback rate in percent (0..100) applied to the paid item amount.
  final double cashbackRate;

  final List<BonusTransaction> transactions;
  final LoyaltyPagination pagination;

  /// Points earned for [orderId] (EARN entries, ledger key `earn:{orderId}`).
  int earnedPointsFor(String orderId) => transactions
      .where((t) => t.type == BonusTransactionType.earn && t.orderId == orderId)
      .fold(0, (sum, t) => sum + t.points);

  @override
  List<Object?> get props => [balance, cashbackRate, transactions, pagination];
}

/// `PromotionFeedItemDto` (ADR-1614): an ACTIVE campaign of the current brand
/// whose window contains now; the feed is ordered `priority DESC, starts_at DESC`.
final class PromotionCampaign extends Equatable {
  const PromotionCampaign({
    required this.id,
    required this.title,
    required this.bannerUrl,
    required this.startsAt,
    required this.endsAt,
    this.description,
    this.actionUrl,
  });

  factory PromotionCampaign.fromJson(Map<String, dynamic> json) {
    try {
      return PromotionCampaign(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        bannerUrl: json['banner_url'] as String,
        actionUrl: json['action_url'] as String?,
        startsAt:
            DateTime.tryParse(json['starts_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endsAt:
            DateTime.tryParse(json['ends_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed promotion campaign payload: $e');
    }
  }

  final String id;
  final String title;
  final String? description;
  final String bannerUrl;
  final String? actionUrl;
  final DateTime startsAt;
  final DateTime endsAt;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    bannerUrl,
    actionUrl,
    startsAt,
    endsAt,
  ];
}
