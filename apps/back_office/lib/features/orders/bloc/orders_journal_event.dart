import 'package:equatable/equatable.dart';

import '../data/models/order.dart';
import 'orders_journal_state.dart';

sealed class OrdersJournalEvent extends Equatable {
  const OrdersJournalEvent();

  @override
  List<Object?> get props => [];
}

/// (Re)load the journal for [branchId] from the first page.
final class OrdersJournalRequested extends OrdersJournalEvent {
  const OrdersJournalRequested({required this.branchId});

  final String branchId;

  @override
  List<Object?> get props => [branchId];
}

/// Server-side status filter; `null` = all statuses.
final class OrdersStatusFilterChanged extends OrdersJournalEvent {
  const OrdersStatusFilterChanged(this.status);

  final OrderStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Client-side period filter over already loaded orders.
final class OrdersDateFilterChanged extends OrdersJournalEvent {
  const OrdersDateFilterChanged(this.filter, {this.customDay});

  final OrdersDateFilter filter;

  /// Concrete day for [OrdersDateFilter.customDay].
  final DateTime? customDay;

  @override
  List<Object?> get props => [filter, customDay];
}

/// Append the next page (contract pagination) to the loaded list.
final class OrdersJournalNextPageRequested extends OrdersJournalEvent {
  const OrdersJournalNextPageRequested();
}

/// Open the receipt/payment details of [orderId]; loads payment lazily.
final class OrderDetailsOpened extends OrdersJournalEvent {
  const OrderDetailsOpened(this.orderId);

  final String orderId;

  @override
  List<Object?> get props => [orderId];
}

/// The details dialog was dismissed.
final class OrderDetailsClosed extends OrdersJournalEvent {
  const OrderDetailsClosed();
}

/// Clears the transient snackbar notice after the UI showed it.
final class OrdersJournalNoticeConsumed extends OrdersJournalEvent {
  const OrdersJournalNoticeConsumed();
}
