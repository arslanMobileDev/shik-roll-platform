import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// How the order is served (UI-806 New Order flow).
enum OrderMode { dineIn, takeaway }

final class OrderModeState extends Equatable {
  const OrderModeState({this.mode = OrderMode.dineIn, this.tableId});

  final OrderMode mode;

  /// Selected table; meaningful only for [OrderMode.dineIn].
  final String? tableId;

  OrderModeState copyWith({OrderMode? mode, Object? tableId = _unset}) {
    return OrderModeState(
      mode: mode ?? this.mode,
      tableId: identical(tableId, _unset) ? this.tableId : tableId as String?,
    );
  }

  static const Object _unset = Object();

  @override
  List<Object?> get props => [mode, tableId];
}

/// Table / takeaway selection for the current order.
class OrderModeCubit extends Cubit<OrderModeState> {
  OrderModeCubit() : super(const OrderModeState());

  void selectDineIn({String? tableId}) {
    emit(OrderModeState(mode: OrderMode.dineIn, tableId: tableId));
  }

  void selectTakeaway() {
    emit(const OrderModeState(mode: OrderMode.takeaway));
  }

  void selectTable(String tableId) {
    emit(state.copyWith(mode: OrderMode.dineIn, tableId: tableId));
  }
}
