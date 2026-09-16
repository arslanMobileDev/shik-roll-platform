import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/cook_shifts_cubit.dart';

class CookShiftsScreen extends StatelessWidget {
  const CookShiftsScreen({super.key});
  String date(DateTime d) => DateFormat(
    'dd.MM.yyyy HH:mm',
  ).format(d.toUtc().add(const Duration(hours: 3)));
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
                      final range = await showDateRangePicker(
                        context: context,
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
                                    DataCell(Text(date(s.clockInAt))),
                                    DataCell(
                                      Text(
                                        s.clockOutAt == null
                                            ? '—'
                                            : date(s.clockOutAt!),
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
