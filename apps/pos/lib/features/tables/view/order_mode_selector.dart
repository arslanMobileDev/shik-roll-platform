import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/pos_config.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/order_mode_cubit.dart';

/// Dine-in / takeaway switch with table selection (UI-806 New Order).
class OrderModeSelector extends StatelessWidget {
  const OrderModeSelector({super.key, this.tables});

  /// Available dine-in tables; defaults to the configured POS directory.
  final List<TableOption>? tables;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderModeCubit, OrderModeState>(
      builder: (context, state) {
        final cubit = context.read<OrderModeCubit>();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<OrderMode>(
              segments: const [
                ButtonSegment(
                  value: OrderMode.dineIn,
                  label: Text('В зале'),
                  icon: Icon(Icons.table_restaurant_outlined),
                ),
                ButtonSegment(
                  value: OrderMode.takeaway,
                  label: Text('Навынос'),
                  icon: Icon(Icons.shopping_bag_outlined),
                ),
              ],
              selected: {state.mode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                if (mode == OrderMode.takeaway) {
                  cubit.selectTakeaway();
                } else {
                  cubit.selectDineIn(tableId: state.tableId);
                }
              },
            ),
            if (state.mode == OrderMode.dineIn) ...[
              const SizedBox(width: AppSpacing.s8),
              _TableDropdown(
                tables: tables ?? PosDirectory.tables,
                selectedTableId: state.tableId,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TableDropdown extends StatelessWidget {
  const _TableDropdown({required this.tables, required this.selectedTableId});

  final List<TableOption> tables;
  final String? selectedTableId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Выбор стола',
      child: PopupMenuButton<String>(
        tooltip: 'Выбор стола',
        onSelected: (tableId) =>
            context.read<OrderModeCubit>().selectTable(tableId),
        itemBuilder: (context) => [
          for (final table in tables)
            PopupMenuItem<String>(
              value: table.id,
              child: Row(
                children: [
                  Icon(
                    table.id == selectedTableId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(table.label),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedTableId == null
                    ? 'Стол не выбран'
                    : tables
                        .firstWhere(
                          (t) => t.id == selectedTableId,
                          orElse: () => TableOption(
                            id: selectedTableId!,
                            label: selectedTableId!,
                          ),
                        )
                        .label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(width: AppSpacing.s4),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
