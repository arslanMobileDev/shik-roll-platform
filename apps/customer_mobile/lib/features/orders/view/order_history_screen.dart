import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/view/auth_flow.dart';
import '../../cart/bloc/cart_event.dart';
import '../../cart/bloc/customer_cart_bloc.dart';
import '../../menu/bloc/menu_bloc.dart';
import '../../menu/bloc/menu_state.dart';
import '../../menu/data/menu_models.dart';
import '../bloc/order_history_bloc.dart';
import '../data/order_history_models.dart';
import 'widgets/order_status_badge.dart';

/// «Мои заказы» tab: the authenticated guest's orders (`GET /orders`)
/// with statuses, totals and the «Повторить заказ» action.
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key, required this.onGoToCart});

  /// Switches the shell to the cart tab after «Повторить заказ».
  final VoidCallback onGoToCart;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    if (context.read<AuthBloc>().state.isAuthenticated) {
      context.read<OrderHistoryBloc>().add(const OrderHistoryStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, next) => previous.status != next.status,
        listener: (context, state) {
          if (state.isAuthenticated) {
            context.read<OrderHistoryBloc>().add(
              const OrderHistoryRefreshed(),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) {
            if (!auth.isAuthenticated) {
              return const _LoginPrompt();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s8,
                    AppSpacing.s16,
                    AppSpacing.s12,
                  ),
                  child: Text('Мои заказы', style: theme.textTheme.headlineSmall),
                ),
                Expanded(child: _OrdersBody(onGoToCart: widget.onGoToCart)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Войдите, чтобы увидеть заказы',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'История заказов привязана к вашему номеру телефона',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton(
              key: const ValueKey('orders-login-button'),
              onPressed: () => showAuthFlowSheet(context),
              child: const Text('Войти по номеру телефона'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersBody extends StatelessWidget {
  const _OrdersBody({required this.onGoToCart});

  final VoidCallback onGoToCart;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderHistoryBloc, OrderHistoryState>(
      builder: (context, state) {
        return switch (state.status) {
          OrderHistoryStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          OrderHistoryStatus.failure => _OrdersError(
            message: state.errorMessage ?? 'Не удалось загрузить заказы',
          ),
          OrderHistoryStatus.loaded when state.orders.isEmpty =>
            const _OrdersEmpty(),
          OrderHistoryStatus.loaded => RefreshIndicator(
            onRefresh: () async => context.read<OrderHistoryBloc>().add(
              const OrderHistoryRefreshed(),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
              ),
              itemCount: state.orders.length,
              itemBuilder: (context, index) => _OrderCard(
                order: state.orders[index],
                onGoToCart: onGoToCart,
              ),
            ),
          ),
        };
      },
    );
  }
}

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.gray400,
          ),
          const SizedBox(height: AppSpacing.s12),
          Text('Заказов пока нет', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Оформите первый заказ в меню',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.gray600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.gray400,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            FilledButton.tonal(
              key: const ValueKey('orders-retry-button'),
              onPressed: () => context.read<OrderHistoryBloc>().add(
                const OrderHistoryRefreshed(),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One order card: number + status badge, date, composition, total and
/// the «Повторить заказ» action.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onGoToCart});

  final OrderHistoryEntry order;
  final VoidCallback onGoToCart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('order-card-${order.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Заказ #${order.orderNumber}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                OrderStatusBadge(status: order.status, type: order.type),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              DateFormat('dd.MM.yyyy, HH:mm').format(order.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            for (final item in order.items) _OrderItemLine(item: item),
            const Divider(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.totalAmount.format(),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  key: ValueKey('repeat-order-${order.id}'),
                  onPressed: () => _repeatOrder(context),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Повторить заказ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Rebuilds cart lines from the order via the loaded menu; dishes that
  /// fell out of the menu (or are stop-listed) are reported, not added.
  void _repeatOrder(BuildContext context) {
    final menu = context.read<MenuBloc>().state;
    final cartBloc = context.read<CustomerCartBloc>();
    final messenger = ScaffoldMessenger.of(context);

    var added = 0;
    final unavailable = <String>[];
    for (final item in order.items) {
      final menuItem = _findMenuItem(menu, item.menuItemId);
      if (menuItem == null || !menuItem.available) {
        unavailable.add(item.name);
        continue;
      }
      cartBloc.add(
        CartItemAdded(
          item: menuItem,
          selection: _selectionFor(menuItem, item),
          quantity: item.quantity,
        ),
      );
      added += item.quantity;
    }

    if (added == 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Блюда из этого заказа сейчас недоступны'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          unavailable.isEmpty
              ? 'Заказ добавлен в корзину'
              : 'Добавлено частично, нет в меню: ${unavailable.join(', ')}',
        ),
        action: SnackBarAction(label: 'В корзину', onPressed: onGoToCart),
      ),
    );
  }

  static MenuItem? _findMenuItem(MenuState menu, String menuItemId) {
    for (final item in menu.items) {
      if (item.id == menuItemId) return item;
    }
    return null;
  }

  /// Maps stored modifier ids back onto the live menu's group ids.
  static Map<String, Set<String>> _selectionFor(
    MenuItem menuItem,
    OrderHistoryItem item,
  ) {
    final selection = <String, Set<String>>{};
    for (final modifier in item.modifiers) {
      for (final group in menuItem.modifierGroups) {
        final exists = group.items.any(
          (option) => option.id == modifier.modifierItemId,
        );
        if (exists) {
          selection
              .putIfAbsent(group.id, () => <String>{})
              .add(modifier.modifierItemId);
        }
      }
    }
    return selection;
  }
}

class _OrderItemLine extends StatelessWidget {
  const _OrderItemLine({required this.item});

  final OrderHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name, style: theme.textTheme.bodyMedium)),
              Text(
                '×${item.quantity}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.gray600,
                ),
              ),
            ],
          ),
          if (item.modifiers.isNotEmpty)
            Text(
              item.modifiersLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.gray600,
              ),
            ),
        ],
      ),
    );
  }
}
