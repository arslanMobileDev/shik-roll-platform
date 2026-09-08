import 'package:equatable/equatable.dart';

import '../data/kds_order_models.dart';
import '../data/kitchen_events_client.dart';

sealed class KdsOrdersEvent extends Equatable {
  const KdsOrdersEvent();

  @override
  List<Object?> get props => [];
}

/// Board start: initial snapshot + kitchen SSE subscription. The branch is
/// derived from the terminal JWT — never from the client (ADR-1618).
final class KdsOrdersStarted extends KdsOrdersEvent {
  const KdsOrdersStarted();
}

/// Manual refresh from the header button.
final class KdsOrdersRefreshed extends KdsOrdersEvent {
  const KdsOrdersRefreshed();
}

/// One-tap cook action: «Начать готовить» → COOKING, «Готово» → READY.
///
/// Kitchen-owned transitions only (ADR-1618): READY → COMPLETED belongs to
/// POS/courier and is never dispatched from this board.
///
/// [cookId]/[shiftId] attribute the transition to the cook currently on the
/// station (audit metadata, not authorization).
final class KdsOrderStatusChangeRequested extends KdsOrdersEvent {
  const KdsOrderStatusChangeRequested({
    required this.orderId,
    required this.status,
    this.cookId,
    this.shiftId,
  });

  final String orderId;
  final KdsOrderStatus status;
  final String? cookId;
  final String? shiftId;

  @override
  List<Object?> get props => [orderId, status, cookId, shiftId];
}

/// New-order highlight consumed by the view (sound played, flash shown).
final class KdsOrdersNewOrdersAcknowledged extends KdsOrdersEvent {
  const KdsOrdersNewOrdersAcknowledged();
}

/// Internal: fallback-polling timer tick (every 15 s while SSE is down).
final class KdsOrdersPollTicked extends KdsOrdersEvent {
  const KdsOrdersPollTicked();
}

/// Internal: a typed signal arrived on the kitchen SSE stream.
final class KdsStreamSignalReceived extends KdsOrdersEvent {
  const KdsStreamSignalReceived(this.signal);

  final KitchenStreamSignal signal;

  @override
  List<Object?> get props => [signal];
}

/// Internal: the SSE connection dropped (error or server close).
final class KdsStreamDropped extends KdsOrdersEvent {
  const KdsStreamDropped();
}

/// Internal: reconnect backoff elapsed — dial the stream again.
final class KdsStreamReconnectTicked extends KdsOrdersEvent {
  const KdsStreamReconnectTicked();
}
