import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../bloc/checkout_cubit.dart';

/// Выбор времени получения: «Как можно скорее» (ASAP, `scheduledAt == null`)
/// или «Ко времени» с выбором слота через [showTimePicker].
class DeliveryTimeSelector extends StatelessWidget {
  const DeliveryTimeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduledAt = context.select<CheckoutCubit, DateTime?>(
      (cubit) => cubit.state.scheduledAt,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          key: const ValueKey('delivery-time-toggle'),
          segments: const [
            ButtonSegment(value: false, label: Text('Как можно скорее')),
            ButtonSegment(value: true, label: Text('Ко времени')),
          ],
          selected: {scheduledAt != null},
          onSelectionChanged: (selection) {
            if (selection.first) {
              _pickTime(context);
            } else {
              context.read<CheckoutCubit>().asapSelected();
            }
          },
        ),
        if (scheduledAt != null) ...[
          const SizedBox(height: AppSpacing.s8),
          OutlinedButton.icon(
            key: const ValueKey('scheduled-time-button'),
            onPressed: () => _pickTime(context),
            icon: const Icon(Icons.schedule_outlined),
            label: Text(_formatTime(scheduledAt)),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final checkout = context.read<CheckoutCubit>();
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: checkout.state.scheduledAt != null
          ? TimeOfDay.fromDateTime(checkout.state.scheduledAt!)
          : now,
    );
    if (picked == null) return;
    final current = DateTime.now();
    var slot = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    );
    // Выбранное время уже прошло сегодня — трактуем как ближайшие сутки.
    if (slot.isBefore(current)) slot = slot.add(const Duration(days: 1));
    checkout.scheduledSelected(slot);
  }

  String _formatTime(DateTime value) =>
      'к ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
