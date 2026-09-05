import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../bloc/orders_journal_bloc.dart';
import '../../bloc/orders_journal_event.dart';
import '../../bloc/orders_journal_state.dart';
import '../../data/models/order.dart';
import 'order_status_badge.dart';

/// Opens the order details dialog and wires it to [OrdersJournalBloc].
Future<void> showOrderDetails(BuildContext context, Order order) {
  final bloc = context.read<OrdersJournalBloc>()..add(OrderDetailsOpened(order.id));
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider<OrdersJournalBloc>.value(
      value: bloc,
      child: OrderDetailsDialog(order: order),
    ),
  ).then((_) {
    if (context.mounted) {
      context.read<OrdersJournalBloc>().add(const OrderDetailsClosed());
    }
  });
}

/// Receipt composition + payment/fiscalization (54-ФЗ) info of one order.
class OrderDetailsDialog extends StatelessWidget {
  const OrderDetailsDialog({super.key, required this.order});

  final Order order;

  static final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Заказ № ${order.orderNumber}',
                          style: textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        OrderStatusBadge(status: order.status),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('orderDetails.close'),
                    tooltip: 'Закрыть',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  _MetaSection(order: order, dateFormat: _dateTimeFormat),
                  const SizedBox(height: 16),
                  _ReceiptSection(order: order),
                  const SizedBox(height: 16),
                  const _PaymentSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.order, required this.dateFormat});

  final Order order;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KeyValueRow('Создан', dateFormat.format(order.createdAt)),
        _KeyValueRow('Тип', order.type.label),
        if (order.tableNumber != null)
          _KeyValueRow('Стол', order.tableNumber!),
        if (order.deliveryAddress != null)
          _KeyValueRow('Адрес', order.deliveryAddress!),
        if (order.comment != null && order.comment!.isNotEmpty)
          _KeyValueRow('Комментарий', order.comment!),
      ],
    );
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Состав чека', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in order.items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.name} × ${item.quantity}',
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(item.totalAmount.format(), style: textTheme.bodyMedium),
            ],
          ),
          for (final modifier in item.modifiers)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '+ ${modifier.name} × ${modifier.quantity}',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  if (modifier.priceDelta.minorUnits != 0)
                    Text(
                      modifier.priceDelta.format(),
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        const Divider(),
        _AmountRow(
          label: 'Подытог',
          amount: order.subtotalAmount.format(),
        ),
        const SizedBox(height: 4),
        _AmountRow(
          label: 'Итого',
          amount: order.totalAmount.format(),
          bold: true,
        ),
      ],
    );
  }
}

/// Payment block: provider, status, amount and fiscalization (54-ФЗ) ids.
class _PaymentSection extends StatelessWidget {
  const _PaymentSection();

  static final DateFormat _dateTimeFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Оплата (54-ФЗ)', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        BlocBuilder<OrdersJournalBloc, OrdersJournalState>(
          buildWhen: (prev, next) =>
              prev.paymentStatus != next.paymentStatus ||
              prev.payment != next.payment,
          builder: (context, state) {
            switch (state.paymentStatus) {
              case OrderPaymentStatus.idle:
              case OrderPaymentStatus.loading:
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              case OrderPaymentStatus.failure:
                return Text(
                  'Не удалось загрузить данные оплаты',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                );
              case OrderPaymentStatus.ready:
                final payment = state.payment;
                if (payment == null) {
                  return Text(
                    'Платёж не зарегистрирован',
                    style: textTheme.bodySmall,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KeyValueRow('Способ оплаты', payment.provider.label),
                    _KeyValueRow('Статус', payment.status.label),
                    _KeyValueRow('Сумма', payment.amount.format()),
                    if (payment.externalPaymentId != null)
                      _KeyValueRow(
                        'ID платежа провайдера',
                        payment.externalPaymentId!,
                      ),
                    _KeyValueRow(
                      'Ключ идемпотентности',
                      payment.idempotenceKey,
                    ),
                    _KeyValueRow(
                      'Зарегистрирован',
                      _dateTimeFormat.format(payment.createdAt),
                    ),
                  ],
                );
            }
          },
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount, this.bold = false});

  final String label;
  final String amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(amount, style: style),
      ],
    );
  }
}
