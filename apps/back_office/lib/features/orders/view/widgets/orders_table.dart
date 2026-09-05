import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import 'order_status_badge.dart';

/// Desktop table of journal orders; a tap opens the receipt details.
class OrdersTable extends StatelessWidget {
  const OrdersTable({
    super.key,
    required this.orders,
    required this.onOpenDetails,
  });

  final List<Order> orders;
  final ValueChanged<Order> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text('Заказ', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 150,
                  child: Text('Создан', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 100,
                  child: Text('Тип', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 150,
                  child: Text('Статус', style: textTheme.bodySmall),
                ),
                Expanded(child: Text('Состав', style: textTheme.bodySmall)),
                SizedBox(
                  width: 110,
                  child: Text('Сумма', style: textTheme.bodySmall),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: orders.isEmpty
                ? const Center(child: Text('Заказы не найдены'))
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) => _OrderRow(
                      order: orders[index],
                      onOpenDetails: onOpenDetails,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onOpenDetails});

  final Order order;
  final ValueChanged<Order> onOpenDetails;

  static final DateFormat _createdFormat = DateFormat('dd.MM.yyyy · HH:mm');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey('orderRow-${order.id}'),
      onTap: () => onOpenDetails(order),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                '№ ${order.orderNumber}',
                style: textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 150,
              child: Text(
                _createdFormat.format(order.createdAt),
                style: textTheme.bodyMedium,
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(order.type.label, style: textTheme.bodyMedium),
            ),
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: OrderStatusBadge(status: order.status),
              ),
            ),
            Expanded(
              child: Text(
                '${order.itemsSummary} · ${order.items.map((i) => i.name).take(2).join(', ')}',
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                order.totalAmount.format(),
                style: textTheme.titleMedium,
              ),
            ),
            const SizedBox(
              width: 40,
              child: Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
