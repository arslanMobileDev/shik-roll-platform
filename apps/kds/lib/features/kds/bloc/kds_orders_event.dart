import 'package:equatable/equatable.dart';

import '../data/kds_order_models.dart';

sealed class KdsOrdersEvent extends Equatable {
  const KdsOrdersEvent();

  @override
  List<Object?> get props => [];
}

/// Board start: initial load + polling subscription.
final class KdsOrdersStarted extends KdsOrdersEvent {
  const KdsOrdersStarted({required this.branchId});

  final String branchId;

  @override
  List<Object?> get props => [branchId];
}

/// Manual refresh from the header button.
final class KdsOrdersRefreshed extends KdsOrdersEvent {
  const KdsOrdersRefreshed();
}

/// Internal timer tick (every [KdsConfig.pollInterval]).
final class KdsOrdersPollTicked extends KdsOrdersEvent {
  const KdsOrdersPollTicked();
}

/// One-tap cook action: «В работу» → COOKING, «Готово» → READY,
/// «Выдано» → COMPLETED.
///
/// [cookId]/[shiftId] attribute the transition to the cook currently on the
/// station (personal author in the order status audit).
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
