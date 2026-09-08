import 'package:flutter/material.dart';

import '../../../core/theme/shik_colors.dart';
import '../../../core/utils/launchers.dart';
import '../../../data/models/courier_order.dart';

/// Карточка заказа доставки: номер, время создания, сумма, адрес, действия.
///
/// Действия по ADR-1617: «Взять доставку» (claim READY), «В пути»
/// (startDelivery), «Доставлен» (completeDelivery). Пока заказ мутирует,
/// его кнопки блокируются.
class CourierOrderCard extends StatelessWidget {
  const CourierOrderCard({
    super.key,
    required this.order,
    required this.updating,
    this.onClaim,
    this.onStart,
    this.onComplete,
    this.onTap,
  });

  final CourierOrder order;
  final bool updating;

  /// «Взять доставку» — неназначенный READY.
  final VoidCallback? onClaim;

  /// «В пути» — собственный READY.
  final VoidCallback? onStart;

  /// «Доставлен» — собственный ON_WAY.
  final VoidCallback? onComplete;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCash = order.paymentMethod == PaymentMethod.cash;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
              if (order.formattedCreatedAt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.formattedCreatedAt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.address.street,
                          style: theme.textTheme.titleMedium,
                        ),
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
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: ShikColors.warning,
                      ),
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
              else
                _ActionArea(
                  order: order,
                  onClaim: onClaim,
                  onStart: onStart,
                  onComplete: onComplete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.order,
    this.onClaim,
    this.onStart,
    this.onComplete,
  });

  final CourierOrder order;
  final VoidCallback? onClaim;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    switch (order.status) {
      case OrderStatus.cooking:
        return FilledButton.tonalIcon(
          onPressed: null,
          icon: const Icon(Icons.soup_kitchen_outlined),
          label: const Text('Ещё готовится'),
        );
      case OrderStatus.ready:
        if (onStart != null) {
          // Own claimed order — start the delivery.
          return FilledButton.icon(
            key: Key('start_${order.id}'),
            onPressed: onStart,
            icon: const Icon(Icons.pedal_bike),
            label: const Text('В пути'),
          );
        }
        if (onClaim != null) {
          return FilledButton.icon(
            key: Key('claim_${order.id}'),
            onPressed: onClaim,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Взять доставку'),
          );
        }
        return const SizedBox.shrink();
      case OrderStatus.onWay:
        if (onComplete == null) return const SizedBox.shrink();
        return FilledButton.icon(
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
          label: const Text('Доставлен'),
        );
      case OrderStatus.completed:
        return const SizedBox.shrink();
    }
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.isCash});

  final bool isCash;

  @override
  Widget build(BuildContext context) {
    final color = isCash ? ShikColors.warning : ShikColors.success;
    final label = isCash
        ? PaymentMethod.cash.label
        : PaymentMethod.onlinePaid.label;
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
