import 'package:equatable/equatable.dart';

/// Клиентская timeline-модель статуса заказа (ADR-1615).
///
/// Backend хранит канонический `OrderStatus` (NEW…COMPLETED/CANCELLED);
/// приложение работает только с этой стабильной проекцией и не зависит
/// от внутренних статусов backend.
enum OrderTimelineStatus {
  pending,
  accepted,
  cooking,
  courierAssigned,
  onWay,
  delivered;

  /// Детерминированный процент прогресса по ADR-1615.
  int get progressPercent => switch (this) {
    OrderTimelineStatus.pending => 5,
    OrderTimelineStatus.accepted => 15,
    OrderTimelineStatus.cooking => 40,
    OrderTimelineStatus.courierAssigned => 55,
    OrderTimelineStatus.onWay => 75,
    OrderTimelineStatus.delivered => 100,
  };

  /// Подпись для чипа статуса в трекере.
  String get label => switch (this) {
    OrderTimelineStatus.pending => 'Принят',
    OrderTimelineStatus.accepted => 'Подтверждён',
    OrderTimelineStatus.cooking => 'Готовится',
    OrderTimelineStatus.courierAssigned => 'Курьер назначен',
    OrderTimelineStatus.onWay => 'В пути',
    OrderTimelineStatus.delivered => 'Доставлен',
  };

  /// Название шага в вертикальном трекере.
  String get stepTitle => switch (this) {
    OrderTimelineStatus.pending => 'Заказ принят',
    OrderTimelineStatus.accepted => 'Заказ подтвержден',
    OrderTimelineStatus.cooking => 'Шеф готовит',
    OrderTimelineStatus.courierAssigned => 'Курьер назначен',
    OrderTimelineStatus.onWay => 'Курьер мчит к вам',
    OrderTimelineStatus.delivered => 'Приятного аппетита!',
  };
}

/// Сырое обновление состояния заказа из backend: событие SSE-стрима
/// `GET /orders/:id/tracking-stream` или ответ snapshot `GET /orders/:id`.
final class OrderTrackingUpdate extends Equatable {
  const OrderTrackingUpdate({
    required this.orderId,
    required this.status,
    this.courierId,
    this.version,
    this.estimatedReadyAt,
    this.timestamp,
  });

  /// Payload SSE-события (`OrderTrackingEvent` на backend).
  factory OrderTrackingUpdate.fromTrackingEvent(Map<String, dynamic> json) {
    try {
      return OrderTrackingUpdate(
        orderId: json['orderId'] as String,
        status: json['status'] as String,
        courierId: json['courierId'] as String?,
        version: (json['version'] as num?)?.toInt(),
        estimatedReadyAt: DateTime.tryParse(
          json['estimatedReadyAt'] as String? ?? '',
        ),
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed tracking event payload: $e');
    }
  }

  /// Payload `OrderEntity` (`GET /orders/:id`): `courierId`/`version` могут
  /// отсутствовать в контракте — тогда дедупликация идёт по проекции.
  factory OrderTrackingUpdate.fromOrderJson(Map<String, dynamic> json) {
    try {
      return OrderTrackingUpdate(
        orderId: json['id'] as String,
        status: json['status'] as String,
        courierId: json['courierId'] as String?,
        version: (json['version'] as num?)?.toInt(),
        estimatedReadyAt: DateTime.tryParse(
          json['estimatedReadyAt'] as String? ?? '',
        ),
        timestamp: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed order payload: $e');
    }
  }

  final String orderId;

  /// Канонический backend-статус (`NEW`, `CONFIRMED`, …, `CANCELLED`).
  final String status;

  final String? courierId;

  /// `orders.version` из backend; `null` для polled-snapshot без версии.
  final int? version;

  /// Расчётное время готовности/доставки заказа, если backend его знает.
  final DateTime? estimatedReadyAt;

  /// Время формирования события/последнего обновления заказа.
  final DateTime? timestamp;

  /// Проекция на клиентскую timeline-модель (ADR-1615).
  OrderTimeline get timeline => timelineWithVersionFloor(0);

  /// Проекция с сохранением version-floor: для snapshot без `version`
  /// (поллинг `GET /orders/:id`) подставляется [fallbackVersion], чтобы
  /// устаревшие версионные события не могли откатить проекцию назад.
  OrderTimeline timelineWithVersionFloor(int fallbackVersion) =>
      OrderTimeline.fromBackendStatus(
        status,
        courierId: courierId,
        orderVersion: version ?? fallbackVersion,
        estimatedDeliveryAt: estimatedReadyAt,
        updatedAt: timestamp,
      );

  @override
  List<Object?> get props => [
    orderId,
    status,
    courierId,
    version,
    estimatedReadyAt,
    timestamp,
  ];
}

/// Проецируемое состояние трекера. [status] равен `null` для отменённого
/// заказа: отмена не входит в линейный прогресс (ADR-1615).
final class OrderTimeline extends Equatable {
  const OrderTimeline._({
    required this.status,
    required this.orderVersion,
    this.estimatedDeliveryAt,
    this.updatedAt,
  });

  factory OrderTimeline.fromBackendStatus(
    String backendStatus, {
    String? courierId,
    int orderVersion = 0,
    DateTime? estimatedDeliveryAt,
    DateTime? updatedAt,
  }) {
    final status = switch (backendStatus) {
      'NEW' => OrderTimelineStatus.pending,
      'CONFIRMED' => OrderTimelineStatus.accepted,
      'COOKING' => OrderTimelineStatus.cooking,
      // READY без назначенного курьера остаётся «готовится» (40%).
      'READY' =>
        courierId != null
            ? OrderTimelineStatus.courierAssigned
            : OrderTimelineStatus.cooking,
      'ON_WAY' => OrderTimelineStatus.onWay,
      'COMPLETED' => OrderTimelineStatus.delivered,
      'CANCELLED' => null,
      // Неизвестный статус — безопасный дефолт начала воронки.
      _ => OrderTimelineStatus.pending,
    };
    return OrderTimeline._(
      status: status,
      orderVersion: orderVersion,
      estimatedDeliveryAt: estimatedDeliveryAt,
      updatedAt: updatedAt,
    );
  }

  /// Текущий шаг timeline; `null` — заказ отменён.
  final OrderTimelineStatus? status;

  /// Версия заказа для дедупликации событий (`<=` текущей игнорируются).
  final int orderVersion;

  /// Расчётное время доставки для блока ETA.
  final DateTime? estimatedDeliveryAt;

  /// Время последнего перехода (подпись активного шага).
  final DateTime? updatedAt;

  bool get isCancelled => status == null;

  int get progressPercent => status?.progressPercent ?? 0;

  @override
  List<Object?> get props => [
    status,
    orderVersion,
    estimatedDeliveryAt,
    updatedAt,
  ];
}
