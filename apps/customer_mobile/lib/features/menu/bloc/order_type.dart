import 'package:flutter_bloc/flutter_bloc.dart';

/// Delivery format switch for the guest (no hall tables on mobile).
enum OrderType { delivery, pickup }

extension OrderTypeLabel on OrderType {
  String get label => switch (this) {
    OrderType.delivery => 'Доставка',
    OrderType.pickup => 'Самовывоз (стойка)',
  };
}

class OrderTypeCubit extends Cubit<OrderType> {
  OrderTypeCubit() : super(OrderType.delivery);

  void select(OrderType type) => emit(type);
}
