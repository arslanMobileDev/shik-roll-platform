import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/orders_journal_bloc.dart';
import '../bloc/orders_journal_event.dart';
import '../bloc/orders_journal_state.dart';
import '../data/models/order.dart';
import 'widgets/order_details_dialog.dart';
import 'widgets/orders_table.dart';

/// Orders journal: status + period filters over a paginated order table
/// with receipt/payment details on row tap.
class OrdersJournalScreen extends StatelessWidget {
  const OrdersJournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrdersJournalBloc, OrdersJournalState>(
      listenWhen: (prev, next) =>
          next.notice != null && prev.notice != next.notice,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.notice!)));
        context.read<OrdersJournalBloc>().add(
          const OrdersJournalNoticeConsumed(),
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            SizedBox(height: 16),
            _StatusFilters(),
            SizedBox(height: 12),
            _DateFilters(),
            SizedBox(height: 16),
            Expanded(child: _Body()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OrdersJournalBloc>().state;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Журнал заказов',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              state.status == OrdersJournalStatus.ready
                  ? 'Показано ${state.visibleOrders.length} из ${state.total}'
                  : 'Загрузка…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters();

  @override
  Widget build(BuildContext context) {
    final selected = context.select<OrdersJournalBloc, OrderStatus?>(
      (bloc) => bloc.state.statusFilter,
    );
    final bloc = context.read<OrdersJournalBloc>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const ValueKey('orders.statusFilter.all'),
          label: const Text('Все'),
          selected: selected == null,
          onSelected: (_) => bloc.add(const OrdersStatusFilterChanged(null)),
        ),
        for (final status in OrderStatus.values)
          ChoiceChip(
            key: ValueKey('orders.statusFilter.${status.wireName}'),
            label: Text(status.label),
            selected: selected == status,
            onSelected: (_) => bloc.add(OrdersStatusFilterChanged(status)),
          ),
      ],
    );
  }
}

class _DateFilters extends StatelessWidget {
  const _DateFilters();

  Future<void> _pickDay(BuildContext context) async {
    final bloc = context.read<OrdersJournalBloc>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: bloc.state.customDay ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      bloc.add(
        OrdersDateFilterChanged(OrdersDateFilter.customDay, customDay: picked),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OrdersJournalBloc>().state;
    final bloc = context.read<OrdersJournalBloc>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final filter in OrdersDateFilter.values)
          if (filter != OrdersDateFilter.customDay)
            ChoiceChip(
              key: ValueKey('orders.dateFilter.${filter.name}'),
              label: Text(filter.label),
              selected: state.dateFilter == filter,
              onSelected: (_) => bloc.add(OrdersDateFilterChanged(filter)),
            ),
        ActionChip(
          key: const ValueKey('orders.dateFilter.pickDay'),
          avatar: const Icon(Icons.calendar_month_rounded, size: 16),
          label: Text(
            state.dateFilter == OrdersDateFilter.customDay &&
                    state.customDay != null
                ? DateFormat('dd.MM.yyyy').format(state.customDay!)
                : OrdersDateFilter.customDay.label,
          ),
          onPressed: () => _pickDay(context),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<OrdersJournalBloc>().state;
    switch (state.status) {
      case OrdersJournalStatus.initial:
      case OrdersJournalStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case OrdersJournalStatus.failure:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Ошибка загрузки'),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('orders.retry'),
                onPressed: () => context.read<OrdersJournalBloc>().add(
                  OrdersJournalRequested(branchId: state.branchId),
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        );
      case OrdersJournalStatus.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: OrdersTable(
                orders: state.visibleOrders,
                onOpenDetails: (order) => showOrderDetails(context, order),
              ),
            ),
            if (state.hasMore) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  key: const ValueKey('orders.loadMore'),
                  onPressed: state.isLoadingMore
                      ? null
                      : () => context.read<OrdersJournalBloc>().add(
                          const OrdersJournalNextPageRequested(),
                        ),
                  icon: state.isLoadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    state.isLoadingMore ? 'Загрузка…' : 'Показать ещё',
                  ),
                ),
              ),
            ],
          ],
        );
    }
  }
}
