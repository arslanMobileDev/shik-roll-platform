import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../bloc/cook_shifts_cubit.dart';
import '../data/cook_shift_models.dart';

final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
final DateFormat _timeFormat = DateFormat('HH:mm');

/// «Смены кухни» — kitchen shift history with per-cook production metrics.
class CookShiftsScreen extends StatelessWidget {
  const CookShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CookShiftsCubit>().state;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Смены кухни', style: textTheme.headlineSmall),
          Text(
            'На линии сейчас: ${state.activeShifts.length} · '
            'выдано заказов: ${state.totalCompletedOrders} шт.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (state.status) {
              CookShiftsStatus.initial ||
              CookShiftsStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              CookShiftsStatus.failure => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.errorMessage ?? 'Ошибка загрузки',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('cookShiftsRetry'),
                      onPressed: () => context.read<CookShiftsCubit>().load(
                        state.branchId,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
              CookShiftsStatus.ready => state.shifts.isEmpty
                  ? const Center(child: Text('Смен пока не было'))
                  : _CookShiftsTable(shifts: state.displayShifts),
            },
          ),
        ],
      ),
    );
  }
}

class _CookShiftsTable extends StatelessWidget {
  const _CookShiftsTable({required this.shifts});

  final List<CookShiftRecord> shifts;

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
                  width: 100,
                  child: Text('Дата', style: textTheme.bodySmall),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Повар', style: textTheme.bodySmall),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Цех', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 80,
                  child: Text('Открыта', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 80,
                  child: Text('Закрыта', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 90,
                  child: Text('Выдано', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 100,
                  child: Text('Ср. время', style: textTheme.bodySmall),
                ),
                SizedBox(
                  width: 160,
                  child: Text('Статус', style: textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: shifts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) =>
                  _CookShiftRow(shift: shifts[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CookShiftRow extends StatelessWidget {
  const _CookShiftRow({required this.shift});

  final CookShiftRecord shift;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avg = shift.avgPrepSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(_dateFormat.format(shift.clockInAt)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              shift.cookName,
              style: textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(flex: 2, child: _RoleChip(role: shift.role)),
          SizedBox(
            width: 80,
            child: Text(_timeFormat.format(shift.clockInAt)),
          ),
          SizedBox(
            width: 80,
            child: Text(
              shift.clockOutAt == null
                  ? '—'
                  : _timeFormat.format(shift.clockOutAt!),
            ),
          ),
          SizedBox(width: 90, child: Text('${shift.completedOrders} шт.')),
          SizedBox(
            width: 100,
            child: Text(avg == null ? '—' : '${(avg / 60).round()} мин'),
          ),
          SizedBox(width: 160, child: _ShiftStatusBadge(active: shift.isActive)),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final CookRole role;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.scaffold,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(
          role.label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.ink),
        ),
      ),
    );
  }
}

class _ShiftStatusBadge extends StatelessWidget {
  const _ShiftStatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.halalGreen : AppColors.inkMuted;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: ValueKey(active ? 'shiftActiveBadge' : 'shiftClosedBadge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.play_circle_fill_rounded : Icons.check_circle,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                active ? 'На смене' : 'Смена закрыта',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
