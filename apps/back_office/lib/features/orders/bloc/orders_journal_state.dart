import 'package:equatable/equatable.dart';

import '../data/models/order.dart';
import '../data/models/order_payment.dart';

enum OrdersJournalStatus { initial, loading, ready, failure }

enum OrderPaymentStatus { idle, loading, ready, failure }

/// Client-side period filter for the journal (the contract exposes no
/// date query params, so filtering applies to loaded orders).
enum OrdersDateFilter {
  all('Всё время'),
  today('Сегодня'),
  yesterday('Вчера'),
  last7Days('7 дней'),
  customDay('Дата');

  const OrdersDateFilter(this.label);

  final String label;
}

final class OrdersJournalState extends Equatable {
  const OrdersJournalState({
    this.status = OrdersJournalStatus.initial,
    this.orders = const [],
    this.branchId = '',
    this.statusFilter,
    this.dateFilter = OrdersDateFilter.all,
    this.customDay,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    this.isLoadingMore = false,
    this.errorMessage,
    this.notice,
    this.selectedOrderId,
    this.paymentStatus = OrderPaymentStatus.idle,
    this.payment,
  });

  final OrdersJournalStatus status;
  final List<Order> orders;

  /// Branch the journal was loaded for.
  final String branchId;

  /// Server-side status filter; `null` = all statuses.
  final OrderStatus? statusFilter;

  /// Client-side period filter.
  final OrdersDateFilter dateFilter;

  /// Concrete day when [dateFilter] is [OrdersDateFilter.customDay].
  final DateTime? customDay;

  /// Contract pagination (PageMeta).
  final int page;
  final int totalPages;
  final int total;

  /// A next-page fetch is in flight.
  final bool isLoadingMore;

  /// Fatal load error.
  final String? errorMessage;

  /// Transient snackbar text (e.g. failed pagination), cleared by the UI.
  final String? notice;

  /// Order whose receipt details are open; `null` = dialog closed.
  final String? selectedOrderId;
  final OrderPaymentStatus paymentStatus;

  /// 54-ФЗ payment record of [selectedOrderId]; `null` = not registered.
  final OrderPayment? payment;

  bool get hasMore => page < totalPages;

  /// Order of [selectedOrderId] within the loaded list, if still present.
  Order? get selectedOrder {
    final id = selectedOrderId;
    if (id == null) return null;
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Orders after the period filter, newest first.
  List<Order> get visibleOrders {
    final filtered = switch (dateFilter) {
      OrdersDateFilter.all => orders,
      OrdersDateFilter.today => _inDay(_startOfDay(DateTime.now())),
      OrdersDateFilter.yesterday => _inDay(
        _startOfDay(DateTime.now()).subtract(const Duration(days: 1)),
      ),
      OrdersDateFilter.last7Days => orders
          .where(
            (o) => !o.createdAt.isBefore(
              _startOfDay(DateTime.now()).subtract(const Duration(days: 6)),
            ),
          )
          .toList(growable: false),
      OrdersDateFilter.customDay => customDay == null
          ? orders
          : _inDay(_startOfDay(customDay!)),
    };
    return [...filtered]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Order> _inDay(DateTime dayStart) => orders
      .where(
        (o) =>
            !o.createdAt.isBefore(dayStart) &&
            o.createdAt.isBefore(dayStart.add(const Duration(days: 1))),
      )
      .toList(growable: false);

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  OrdersJournalState copyWith({
    OrdersJournalStatus? status,
    List<Order>? orders,
    String? branchId,
    OrderStatus? statusFilter,
    bool clearStatusFilter = false,
    OrdersDateFilter? dateFilter,
    DateTime? customDay,
    bool clearCustomDay = false,
    int? page,
    int? totalPages,
    int? total,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
    String? selectedOrderId,
    bool clearSelection = false,
    OrderPaymentStatus? paymentStatus,
    OrderPayment? payment,
    bool clearPayment = false,
  }) {
    return OrdersJournalState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      branchId: branchId ?? this.branchId,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      dateFilter: dateFilter ?? this.dateFilter,
      customDay: clearCustomDay ? null : (customDay ?? this.customDay),
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      selectedOrderId: clearSelection
          ? null
          : (selectedOrderId ?? this.selectedOrderId),
      paymentStatus: paymentStatus ?? this.paymentStatus,
      payment: clearPayment ? null : (payment ?? this.payment),
    );
  }

  @override
  List<Object?> get props => [
    status,
    orders,
    branchId,
    statusFilter,
    dateFilter,
    customDay,
    page,
    totalPages,
    total,
    isLoadingMore,
    errorMessage,
    notice,
    selectedOrderId,
    paymentStatus,
    payment,
  ];
}
