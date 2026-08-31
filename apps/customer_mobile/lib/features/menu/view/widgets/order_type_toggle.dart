import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/order_type.dart';

/// Header switch between delivery and counter pickup (no hall tables).
class OrderTypeToggle extends StatelessWidget {
  const OrderTypeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<OrderTypeCubit>().state;
    return BlocBuilder<OrderTypeCubit, OrderType>(
      builder: (context, _) {
        return SegmentedButton<OrderType>(
          key: const ValueKey('order-type-toggle'),
          segments: const [
            ButtonSegment(
              value: OrderType.delivery,
              label: Text('Доставка'),
              icon: Icon(Icons.delivery_dining_outlined),
            ),
            ButtonSegment(
              value: OrderType.pickup,
              label: Text('Самовывоз (стойка)'),
              icon: Icon(Icons.shopping_bag_outlined),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (selection) =>
              context.read<OrderTypeCubit>().select(selection.first),
        );
      },
    );
  }
}
