import 'package:flutter_bloc/flutter_bloc.dart';

/// Minimal guest cart: counts added line items; shown as the badge in the
/// bottom navigation. The real cart feature lands with checkout.
class CartCountCubit extends Cubit<int> {
  CartCountCubit() : super(0);

  void addItem() => emit(state + 1);
}
