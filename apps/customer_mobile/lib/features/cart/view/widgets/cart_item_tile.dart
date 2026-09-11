import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../bloc/cart_event.dart';
import '../../bloc/customer_cart_bloc.dart';
import '../../data/cart_line.dart';

/// One cart position: dish name with modifiers, unit and line totals,
/// [-] quantity [+] stepper and a delete button.
class CartItemTile extends StatelessWidget {
  const CartItemTile({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartBloc = context.read<CustomerCartBloc>();
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.item.name, style: theme.textTheme.titleSmall),
                      if (line.modifiers.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          line.modifiersLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '${line.unitPrice.format()} / шт',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(line.total.format(), style: theme.textTheme.titleSmall),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: ValueKey('qty-minus-${line.id}'),
                  onPressed: () => cartBloc.add(
                    CartLineQuantityChanged(lineId: line.id, delta: -1),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Убавить',
                ),
                Text('${line.quantity}', style: theme.textTheme.titleSmall),
                IconButton(
                  key: ValueKey('qty-plus-${line.id}'),
                  onPressed: () => cartBloc.add(
                    CartLineQuantityChanged(lineId: line.id, delta: 1),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Прибавить',
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('remove-${line.id}'),
                  onPressed: () =>
                      cartBloc.add(CartLineRemoved(lineId: line.id)),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.gray600,
                  ),
                  tooltip: 'Удалить',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
