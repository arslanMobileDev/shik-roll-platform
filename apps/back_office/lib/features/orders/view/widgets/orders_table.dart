import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/order.dart';
import 'order_status_badge.dart';

final DateFormat _createdFormat = DateFormat('dd.MM.yyyy · HH:mm');

/// Journal orders — a table on desktop, stacked cards on phones. A tap opens
/// the receipt details either way.
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
    if (AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)) {
      if (orders.isEmpty) return const Center(child: Text('Заказы не найдены'));
      return ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _OrderCard(order: orders[index], onOpenDetails: onOpenDetails),
      );
    }
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
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone layout of [_OrderRow]: same data, same tap key, stacked.
/// Material carries the background so the ink ripple stays visible.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onOpenDetails});

  final Order order;
  final ValueChanged<Order> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        key: ValueKey('orderRow-${order.id}'),
        onTap: () => onOpenDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '№ ${order.orderNumber}',
                      style: textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.totalAmount.format(),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Wrap, not Row: the badge plus the type must never overflow a
              // narrow screen — they just move onto the next line.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OrderStatusBadge(status: order.status),
                  Text(order.type.label, style: textTheme.bodySmall),
                ],
              ),
              Text(
                '${_createdFormat.format(order.createdAt)} · '
                '${order.itemsSummary} · '
                '${order.items.map((i) => i.name).take(2).join(', ')}',
                style: textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
