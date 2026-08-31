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
final class KdsOrderStatusChangeRequested extends KdsOrdersEvent {
  const KdsOrderStatusChangeRequested({
    required this.orderId,
    required this.status,
  });

  final String orderId;
  final KdsOrderStatus status;

  @override
  List<Object?> get props => [orderId, status];
}

/// New-order highlight consumed by the view (sound played, flash shown).
final class KdsOrdersNewOrdersAcknowledged extends KdsOrdersEvent {
  const KdsOrdersNewOrdersAcknowledged();
}
