import 'package:equatable/equatable.dart';

import '../data/kds_order_models.dart';

sealed class KdsOrdersState extends Equatable {
  const KdsOrdersState();

  /// Orders available for rendering, if the board has any data.
  List<KdsOrder>? get orders => null;

  /// Ids that arrived with the latest fetch — used for audio/visual
  /// new-order feedback. Empty once acknowledged by the view.
  Set<String> get freshOrderIds => const {};

  @override
  List<Object?> get props => [];
}

/// Initial load in progress (board has no data yet).
final class KdsOrdersLoading extends KdsOrdersState {
  const KdsOrdersLoading();
}

/// Board data available. Also the resting state after actions/polls.
final class KdsOrdersLoaded extends KdsOrdersState {
  const KdsOrdersLoaded({
    required this.orders,
    this.lastUpdatedAt,
    this.freshOrderIds = const {},
    this.actionError,
  });

  @override
  final List<KdsOrder> orders;

  final DateTime? lastUpdatedAt;

  @override
  final Set<String> freshOrderIds;

  /// Transient status-change failure, surfaced as a snackbar by the view.
  final String? actionError;

  KdsOrdersLoaded copyWith({
    List<KdsOrder>? orders,
    DateTime? lastUpdatedAt,
    Set<String>? freshOrderIds,
    String? Function()? actionError,
  }) => KdsOrdersLoaded(
    orders: orders ?? this.orders,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    freshOrderIds: freshOrderIds ?? this.freshOrderIds,
    actionError: actionError != null ? actionError() : this.actionError,
  );

  @override
  List<Object?> get props => [
    orders,
    lastUpdatedAt,
    freshOrderIds,
    actionError,
  ];
}

/// A status transition is being sent to the API; the board stays visible and
/// the affected card shows an in-progress affordance.
final class KdsOrdersActionInProgress extends KdsOrdersState {
  const KdsOrdersActionInProgress({
    required this.orders,
    required this.pendingOrderId,
  });

  @override
  final List<KdsOrder> orders;

  final String pendingOrderId;

  @override
  List<Object?> get props => [orders, pendingOrderId];
}

/// Fetch failed before any data was available.
final class KdsOrdersError extends KdsOrdersState {
  const KdsOrdersError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
