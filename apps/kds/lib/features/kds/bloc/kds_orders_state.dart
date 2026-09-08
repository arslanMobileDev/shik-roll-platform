import 'package:equatable/equatable.dart';

import '../data/kds_order_models.dart';

/// Realtime transport state of the board (ADR-1618 recovery contract).
enum KdsConnectionStatus {
  /// Dialling or re-dialling the kitchen SSE stream.
  connecting,

  /// SSE live — order events arrive push-style.
  live,

  /// SSE down after repeated reconnects — 15 s snapshot polling fallback.
  polling,
}

sealed class KdsOrdersState extends Equatable {
  const KdsOrdersState();

  /// Orders available for rendering, if the board has any data.
  List<KdsOrder>? get orders => null;

  /// Ids that newly arrived in CONFIRMED since the last acknowledgement —
  /// used for audio/visual new-order feedback.
  Set<String> get freshOrderIds => const {};

  /// Realtime transport state (connecting / live / polling fallback).
  KdsConnectionStatus get connection => KdsConnectionStatus.connecting;

  /// Orders with a status transition in flight — their cards are blocked.
  Set<String> get mutatingOrderIds => const {};

  /// `serverTime − localTime` from the latest snapshot/heartbeat; delay
  /// timers add it to the local clock so server-stamped ages stay true.
  Duration get serverClockOffset => Duration.zero;

  @override
  List<Object?> get props => [];
}

/// Initial load in progress (board has no data yet).
final class KdsOrdersLoading extends KdsOrdersState {
  const KdsOrdersLoading();
}

/// Board data available — the steady state for snapshots, stream events and
/// optimistic mutations.
final class KdsOrdersLoaded extends KdsOrdersState {
  const KdsOrdersLoaded({
    required this.orders,
    this.lastUpdatedAt,
    this.freshOrderIds = const {},
    this.actionError,
    this.connection = KdsConnectionStatus.connecting,
    this.mutatingOrderIds = const {},
    this.serverClockOffset = Duration.zero,
  });

  @override
  final List<KdsOrder> orders;

  final DateTime? lastUpdatedAt;

  @override
  final Set<String> freshOrderIds;

  /// Transient status-change failure (with the backend error code), surfaced
  /// as a snackbar by the view.
  final String? actionError;

  @override
  final KdsConnectionStatus connection;

  @override
  final Set<String> mutatingOrderIds;

  @override
  final Duration serverClockOffset;

  KdsOrdersLoaded copyWith({
    List<KdsOrder>? orders,
    DateTime? lastUpdatedAt,
    Set<String>? freshOrderIds,
    String? Function()? actionError,
    KdsConnectionStatus? connection,
    Set<String>? mutatingOrderIds,
    Duration? serverClockOffset,
  }) => KdsOrdersLoaded(
    orders: orders ?? this.orders,
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    freshOrderIds: freshOrderIds ?? this.freshOrderIds,
    actionError: actionError != null ? actionError() : this.actionError,
    connection: connection ?? this.connection,
    mutatingOrderIds: mutatingOrderIds ?? this.mutatingOrderIds,
    serverClockOffset: serverClockOffset ?? this.serverClockOffset,
  );

  @override
  List<Object?> get props => [
    orders,
    lastUpdatedAt,
    freshOrderIds,
    actionError,
    connection,
    mutatingOrderIds,
    serverClockOffset,
  ];
}

/// Fetch failed before any data was available.
final class KdsOrdersError extends KdsOrdersState {
  const KdsOrdersError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
