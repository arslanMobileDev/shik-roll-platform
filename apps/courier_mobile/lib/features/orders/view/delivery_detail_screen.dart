import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/shik_colors.dart';
import '../../../core/utils/launchers.dart';
import '../../../data/models/courier_order.dart';
import '../bloc/orders_cubit.dart';
import '../bloc/orders_state.dart';

/// Детали доставки (ADR-1617): полный адрес, комментарий клиента, звонок и
/// действия «Взять доставку» (claim READY), «В пути» (READY -> ON_WAY),
/// «Доставлен» (ON_WAY -> COMPLETED).
class DeliveryDetailScreen extends StatelessWidget {
  const DeliveryDetailScreen({super.key, required this.orderId});

  final String orderId;

  CourierOrder? _find(OrdersState state) {
    if (state is! OrdersLoaded) return null;
    for (final order in state.orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrdersCubit, OrdersState>(
      listener: (context, state) {
        if (state is OrdersFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
        // Заказ доставлен и выпал из активного списка — закрываем детали.
        // isCurrent: не даем повторной эмиссии сделать pop уже закрытого
        // роута (иначе снимется и экран списка под ним).
        if (state is OrdersLoaded &&
            _find(state) == null &&
            (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final order = _find(state);
        if (order == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final loaded = state as OrdersLoaded;
        return _DeliveryDetailView(
          order: order,
          courierId: loaded.courierId,
          updating: loaded.mutatingOrderId == order.id,
        );
      },
    );
  }
}

class _DeliveryDetailView extends StatelessWidget {
  const _DeliveryDetailView({
    required this.order,
    required this.courierId,
    required this.updating,
  });

  final CourierOrder order;
  final String courierId;
  final bool updating;

  Future<void> _confirmComplete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Заказ #${order.number} доставлен?'),
        content: const Text('Подтвердите передачу заказа клиенту.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('confirm_complete_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Да, доставлено'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<OrdersCubit>().completeDelivery(order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCash = order.paymentMethod == PaymentMethod.cash;

    return Scaffold(
      appBar: AppBar(title: Text('Заказ #${order.number}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatusChip(status: order.status),
              const Spacer(),
              if (order.formattedCreatedAt.isNotEmpty)
                Text(
                  'Создан в ${order.formattedCreatedAt}',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            icon: Icons.location_on,
            title: 'Адрес доставки',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.address.street, style: theme.textTheme.titleMedium),
                if (order.address.detailsLine.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      order.address.detailsLine,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          if (order.clientComment?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            _Section(
              icon: Icons.chat_bubble_outline,
              title: 'Комментарий клиента',
              iconColor: ShikColors.warning,
              child: Text(
                order.clientComment!,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Section(
            icon: Icons.payments_outlined,
            title: 'Оплата',
            child: Row(
              children: [
                Text(order.formattedTotal, style: theme.textTheme.titleLarge),
                const SizedBox(width: 12),
                _PaymentBadge(isCash: isCash),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('detail_call_client'),
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
                key: const Key('detail_open_navigator'),
                tooltip: 'Навигатор',
                onPressed: () => Launchers.openNavigator(order),
                icon: const Icon(Icons.navigation),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _ActionButton(
            order: order,
            courierId: courierId,
            updating: updating,
            onComplete: () => _confirmComplete(context),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.order,
    required this.courierId,
    required this.updating,
    required this.onComplete,
  });

  final CourierOrder order;
  final String courierId;
  final bool updating;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (updating) {
      return const Center(child: CircularProgressIndicator());
    }
    final cubit = context.read<OrdersCubit>();
    final isOwn = order.courierId == courierId;

    return switch (order.status) {
      OrderStatus.cooking => FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.soup_kitchen_outlined),
        label: const Text('Ещё готовится'),
      ),
      // Неназначенный READY: «Взять доставку» (claim).
      OrderStatus.ready when order.courierId == null => FilledButton.icon(
        key: Key('detail_claim_${order.id}'),
        onPressed: () => cubit.claim(order.id),
        icon: const Icon(Icons.shopping_bag_outlined),
        label: const Text('Взять доставку'),
      ),
      // Собственный READY: «В пути».
      OrderStatus.ready when isOwn => FilledButton.icon(
        key: Key('detail_start_${order.id}'),
        onPressed: () => cubit.startDelivery(order.id),
        icon: const Icon(Icons.pedal_bike),
        label: const Text('В пути'),
      ),
      // Собственный ON_WAY: «Доставлен» с подтверждением.
      OrderStatus.onWay when isOwn => FilledButton.icon(
        key: Key('detail_complete_${order.id}'),
        style: FilledButton.styleFrom(
          backgroundColor: ShikColors.success,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        onPressed: onComplete,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Доставлен'),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(title, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.cooking => ('Готовится', ShikColors.warning),
      OrderStatus.ready => ('Готов к выдаче', ShikColors.terracotta),
      OrderStatus.onWay => ('В пути', ShikColors.halalGreen),
      OrderStatus.completed => ('Доставлен', ShikColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.isCash});

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
