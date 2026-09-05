import 'package:flutter/material.dart';

import '../../../core/theme/shik_colors.dart';
import '../../../core/utils/launchers.dart';
import '../../../data/models/courier_order.dart';

/// Карточка заказа доставки: номер, сумма, адрес, контакты, действия.
class CourierOrderCard extends StatelessWidget {
  const CourierOrderCard({
    super.key,
    required this.order,
    required this.updating,
    this.onPickup,
    this.onComplete,
  });

  final CourierOrder order;
  final bool updating;
  final VoidCallback? onPickup;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCash = order.paymentMethod == PaymentMethod.cash;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.number}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  order.formattedTotal,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                _PaymentChip(isCash: isCash),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.address.street,
                          style: theme.textTheme.titleMedium),
                      if (order.address.detailsLine.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            order.address.detailsLine,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (order.clientComment?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ShikColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 16, color: ShikColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order.clientComment!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('call_client_${order.id}'),
                    onPressed: () => Launchers.callClient(order.clientPhone),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(
                      order.clientPhone,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: Key('open_navigator_${order.id}'),
                  tooltip: 'Навигатор',
                  onPressed: () => Launchers.openNavigator(order),
                  icon: const Icon(Icons.navigation),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (updating)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (order.status == OrderStatus.ready && onPickup != null)
              FilledButton.icon(
                key: Key('pickup_${order.id}'),
                onPressed: onPickup,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Забрал заказ'),
              )
            else if (order.status == OrderStatus.delivering &&
                onComplete != null)
              FilledButton.icon(
                key: Key('complete_${order.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: ShikColors.success,
                  minimumSize: const Size.fromHeight(64),
                  textStyle: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: onComplete,
                icon: const Icon(Icons.check_circle_outline, size: 28),
                label: const Text('Доставлено'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.isCash});

  final bool isCash;

  @override
  Widget build(BuildContext context) {
    final color = isCash ? ShikColors.warning : ShikColors.success;
    final label =
        isCash ? PaymentMethod.cash.label : PaymentMethod.onlinePaid.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
