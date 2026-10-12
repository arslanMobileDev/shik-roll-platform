import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shik_date_picker.dart';
import '../bloc/cook_shifts_cubit.dart';
import '../data/cook_shift_models.dart';

String _date(DateTime d) => DateFormat(
  'dd.MM.yyyy HH:mm',
).format(d.toUtc().add(const Duration(hours: 3)));

class CookShiftsScreen extends StatelessWidget {
  const CookShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CookShiftsCubit>();
    final state = cubit.state;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Смены кухни', style: Theme.of(context).textTheme.headlineSmall),
          Text(
            'На линии сейчас: ${state.activeShifts.length} · выдано заказов: ${state.totalCompletedOrders} шт.',
          ),
          const Text('Счётчик: заказы, принятые в приготовление · МСК'),
          Wrap(
            spacing: 8,
            children: [
              for (final p in {
                'today': 'Сегодня',
                'week': 'Неделя',
                'month': 'Месяц',
                'custom': 'Дата',
              }.entries)
                ChoiceChip(
                  label: Text(p.value),
                  selected: state.period == p.key,
                  onSelected: (_) async {
                    if (p.key == 'custom') {
                      final now = DateTime.now();
                      final range = await showShikDateRangePicker(
                        context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(now.year + 1),
                      );
                      if (range != null && !cubit.isClosed) {
                        await cubit.load(
                          state.branchId,
                          period: 'custom',
                          dateFrom: range.start,
                          dateTo: range.end,
                        );
                      }
                    } else {
                      await cubit.load(state.branchId, period: p.key);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (state.status) {
              CookShiftsStatus.initial || CookShiftsStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              CookShiftsStatus.failure => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.errorMessage ?? 'Ошибка загрузки'),
                    FilledButton(
                      key: const Key('cookShiftsRetry'),
                      onPressed: () => cubit.load(state.branchId),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
              CookShiftsStatus.ready =>
                state.shifts.isEmpty
                    ? const Center(child: Text('Смен пока не было'))
                    : AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width)
                    ? ListView.separated(
                        itemCount: state.displayShifts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _ShiftCard(shift: state.displayShifts[index]),
                      )
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              for (final text in [
                                'Повар',
                                'Терминал',
                                'Начало',
                                'Окончание',
                                'Длительность',
                                'Заказов',
                                'Среднее время',
                                'Статус',
                              ])
                                DataColumn(label: Text(text)),
                            ],
                            rows: [
                              for (final s in state.displayShifts)
                                DataRow(
                                  color: WidgetStatePropertyAll(
                                    s.isActive
                                        ? Colors.green.withValues(alpha: 0.08)
                                        : Colors.white,
                                  ),
                                  cells: [
                                    DataCell(Text(s.cookName)),
                                    DataCell(Text(s.terminalCode)),
                                    DataCell(Text(_date(s.clockInAt))),
                                    DataCell(
                                      Text(
                                        s.clockOutAt == null
                                            ? '—'
                                            : _date(s.clockOutAt!),
                                      ),
                                    ),
                                    DataCell(Text('${s.durationMinutes} мин')),
                                    DataCell(Text('${s.completedOrders} шт.')),
                                    DataCell(
                                      Text(
                                        s.avgPrepSeconds == null
                                            ? '—'
                                            : '${(s.avgPrepSeconds! / 60).toStringAsFixed(1)} мин',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        s.isActive
                                            ? 'На смене'
                                            : 'Смена закрыта',
                                        key: ValueKey(
                                          s.isActive
                                              ? 'shiftActiveBadge'
                                              : 'shiftClosedBadge',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
            },
          ),
        ],
      ),
    );
  }
}

/// Phone layout of a `DataTable` row: same metrics, same badge keys, stacked.
/// The value strings match the table cells byte for byte on purpose — the
/// desktop tests then double as a parity check for the cards.
class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift});

  final CookShiftRecord shift;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: shift.isActive
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shift.cookName,
                  style: textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                shift.isActive ? 'На смене' : 'Смена закрыта',
                key: ValueKey(
                  shift.isActive ? 'shiftActiveBadge' : 'shiftClosedBadge',
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: shift.isActive
                      ? AppColors.success
                      : AppColors.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${shift.terminalCode} · ${_date(shift.clockInAt)} → '
            '${shift.clockOutAt == null ? '—' : _date(shift.clockOutAt!)}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final metric in [
                'Длительность ${shift.durationMinutes} мин',
                'Заказов ${shift.completedOrders} шт.',
                'Среднее ${shift.avgPrepSeconds == null ? '—' : '${(shift.avgPrepSeconds! / 60).toStringAsFixed(1)} мин'}',
              ])
                Text(metric, style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
