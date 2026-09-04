import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cart/data/orders_repository.dart';
import '../data/order_history_models.dart';
import '../data/order_history_repository.dart';

/// Commands accepted by [OrderHistoryBloc].
sealed class OrderHistoryEvent extends Equatable {
  const OrderHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// First load when the orders tab opens for an authenticated guest.
final class OrderHistoryStarted extends OrderHistoryEvent {
  const OrderHistoryStarted();
}

/// Pull-to-refresh and post-login reload.
final class OrderHistoryRefreshed extends OrderHistoryEvent {
  const OrderHistoryRefreshed();
}

enum OrderHistoryStatus { loading, loaded, failure }

final class OrderHistoryState extends Equatable {
  const OrderHistoryState({
    this.status = OrderHistoryStatus.loading,
    this.orders = const [],
    this.errorMessage,
  });

  final OrderHistoryStatus status;
  final List<OrderHistoryEntry> orders;
  final String? errorMessage;

  OrderHistoryState copyWith({
    OrderHistoryStatus? status,
    List<OrderHistoryEntry>? orders,
    String? errorMessage,
  }) {
    return OrderHistoryState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, orders, errorMessage];
}

/// Loads the guest's orders through [OrderHistoryRepository]; the Bearer
/// token is attached by the repository from the live auth session.
class OrderHistoryBloc extends Bloc<OrderHistoryEvent, OrderHistoryState> {
  OrderHistoryBloc({required this._repository})
    : super(const OrderHistoryState()) {
    on<OrderHistoryStarted>(_onLoad);
    on<OrderHistoryRefreshed>(_onLoad);
  }

  final OrderHistoryRepository _repository;

  Future<void> _onLoad(
    OrderHistoryEvent event,
    Emitter<OrderHistoryState> emit,
  ) async {
    emit(state.copyWith(status: OrderHistoryStatus.loading));
    try {
      final orders = await _repository.getOrders();
      emit(
        OrderHistoryState(status: OrderHistoryStatus.loaded, orders: orders),
      );
    } on OrdersException catch (e) {
      emit(
        state.copyWith(
          status: OrderHistoryStatus.failure,
          errorMessage: e.message,
        ),
      );
    }
  }
}
