import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/halal_badge.dart';
import '../../../data/models/courier_order.dart';
import '../../../data/models/courier_session.dart';
import '../../../data/repositories/courier_repository.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../bloc/orders_cubit.dart';
import '../bloc/orders_state.dart';
import '../widgets/courier_order_card.dart';

/// Экран активных доставок: «К забору с кухни» / «Мои текущие».
class CourierOrdersScreen extends StatelessWidget {
  const CourierOrdersScreen({super.key, required this.session});

  final CourierSession session;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrdersCubit(
        repository: context.read<CourierRepository>(),
        session: session,
      )..load(),
      child: const _CourierOrdersView(),
    );
  }
}

class _CourierOrdersView extends StatelessWidget {
  const _CourierOrdersView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHIK ROLL Курьер', style: theme.textTheme.titleMedium),
            BlocBuilder<OrdersCubit, OrdersState>(
              builder: (context, state) => Text(
                state is OrdersLoaded
                    ? 'Активных: '
                        '${state.pickupOrders.length + state.myOrders.length}'
                    : '',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: HalalBadge(compact: true),
          ),
        ],
      ),
      drawer: const _CourierDrawer(),
      body: BlocConsumer<OrdersCubit, OrdersState>(
        listener: (context, state) {
          if (state is OrdersFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          return switch (state) {
            OrdersLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            OrdersFailure(message: final message) => _ErrorState(
                message: message,
                onRetry: () => context.read<OrdersCubit>().load(),
              ),
            OrdersLoaded() => _LoadedBody(state: state),
          };
        },
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state});

  final OrdersLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<OrdersTab>(
            key: const Key('orders_tab_switcher'),
            segments: [
              ButtonSegment(
                value: OrdersTab.pickup,
                label: Text('К забору (${state.pickupOrders.length})'),
                icon: const Icon(Icons.soup_kitchen_outlined),
              ),
              ButtonSegment(
                value: OrdersTab.mine,
                label: Text('Мои текущие (${state.myOrders.length})'),
                icon: const Icon(Icons.pedal_bike),
              ),
            ],
            selected: {state.tab},
            onSelectionChanged: (selection) =>
                cubit.selectTab(selection.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.load,
            child: _OrdersList(state: state),
          ),
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.state});

  final OrdersLoaded state;

  Future<void> _confirmComplete(
    BuildContext context,
    String orderId,
    String number,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Заказ #$number доставлен?'),
        content: const Text('Подтвердите передачу заказа клиенту.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Да, доставлено'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<OrdersCubit>().completeOrder(orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = state.ordersFor(state.tab);
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            state.tab == OrdersTab.pickup
                ? Icons.soup_kitchen_outlined
                : Icons.pedal_bike,
            size: 56,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 12),
          Text(
            state.tab == OrdersTab.pickup
                ? 'Нет заказов к забору'
                : 'Нет заказов в пути',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return CourierOrderCard(
          order: order,
          updating: state.updatingOrderId == order.id,
          onPickup: order.status == OrderStatus.ready
              ? () => context.read<OrdersCubit>().pickupOrder(order.id)
              : null,
          onComplete: order.status == OrderStatus.delivering
              ? () => _confirmComplete(context, order.id, order.number)
              : null,
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _CourierDrawer extends StatelessWidget {
  const _CourierDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: HalalBadge(),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                key: const Key('logout_button'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<AuthCubit>().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
