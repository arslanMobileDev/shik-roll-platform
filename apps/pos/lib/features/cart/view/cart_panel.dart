import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/pos_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../tables/bloc/order_mode_cubit.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import '../domain/cart_line.dart';

/// UI-806 Global Components — cart panel for the cashier screen.
///
/// Shows the order mode context, cart lines with quantity steppers and
/// the exact RUB total.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key, this.onCheckout});

  /// Checkout is out of scope for the UI-803 baseline; the host decides
  /// what happens when the cashier confirms the order.
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CartHeader(),
        const Divider(),
        Expanded(
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state.isEmpty) {
                return const EmptyView(
                  title: 'Корзина пуста',
                  message: 'Добавьте позиции из каталога',
                  icon: Icons.shopping_cart_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.s12),
                itemCount: state.lines.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.s8),
                itemBuilder: (context, index) =>
                    _CartLineTile(line: state.lines[index]),
              );
            },
          ),
        ),
        const Divider(),
        BlocBuilder<CartBloc, CartState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Итого', style: textTheme.titleMedium),
                      Text(
                        state.total.format(),
                        style: textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  FilledButton.icon(
                    onPressed: state.isEmpty ? null : onCheckout,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('К оплате'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextButton.icon(
                    onPressed: state.isEmpty
                        ? null
                        : () => context.read<CartBloc>().add(
                            const CartCleared(),
                          ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Очистить'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Текущий заказ',
              style: textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          BlocBuilder<OrderModeCubit, OrderModeState>(
            builder: (context, modeState) {
              final label = modeState.mode == OrderMode.takeaway
                  ? 'Навынос'
                  : 'В зале${modeState.tableId != null ? ' · ${_tableLabel(modeState.tableId!)}' : ''}';
              return Chip(
                avatar: Icon(
                  modeState.mode == OrderMode.takeaway
                      ? Icons.shopping_bag_outlined
                      : Icons.table_restaurant_outlined,
                  size: 18,
                ),
                label: Text(label),
              );
            },
          ),
        ],
      ),
    );
  }

  String _tableLabel(String tableId) {
    return PosDirectory.tables
        .where((t) => t.id == tableId)
        .map((t) => t.label)
        .firstOrNull ?? tableId;
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cart = context.read<CartBloc>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Удалить позицию',
                icon: const Icon(Icons.close, size: 20),
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                onPressed: () => cart.add(CartLineRemoved(line.key)),
              ),
            ],
          ),
          if (line.modifiers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              line.modifiers.map((m) => m.optionName).join(', '),
              style: textTheme.bodySmall?.copyWith(color: AppColors.gray600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              _QuantityStepper(line: line),
              const Spacer(),
              Text(line.total.format(), style: textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartBloc>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          tooltip: 'Уменьшить количество',
          onPressed: () =>
              cart.add(CartLineQuantityChanged(line.key, line.quantity - 1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          child: Text(
            '${line.quantity}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          tooltip: 'Увеличить количество',
          onPressed: () =>
              cart.add(CartLineQuantityChanged(line.key, line.quantity + 1)),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed,
    );
  }
}
