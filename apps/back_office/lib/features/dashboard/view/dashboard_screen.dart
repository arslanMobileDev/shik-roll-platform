import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/dashboard_state.dart';
import '../data/models/revenue_summary.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  String _money(num value) => NumberFormat.currency(
    locale: 'ru',
    symbol: '₽',
    decimalDigits: 2,
  ).format(value);
  String _date(DateTime value) => DateFormat('dd.MM.yyyy', 'ru').format(value);

  Future<void> _choose(BuildContext context, DashboardState state) async {
    final cubit = context.read<DashboardCubit>();
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: state.dateFrom != null && state.dateTo != null
          ? DateTimeRange(start: state.dateFrom!, end: state.dateTo!)
          : null,
      helpText: 'Период выручки · Москва',
      saveText: 'Применить',
      cancelText: 'Отмена',
      fieldStartLabelText: 'Начало',
      fieldEndLabelText: 'Конец',
    );
    if (range != null && context.mounted) {
      await cubit.select(
        DashboardPeriod.custom,
        from: range.start,
        to: range.end,
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<DashboardCubit, DashboardState>(
    builder: (context, state) {
      if (state.status == DashboardStatus.initial ||
          state.status == DashboardStatus.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.status == DashboardStatus.error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.read<DashboardCubit>().refresh(),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        );
      }
      final revenue = state.revenue!;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Выручка',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: () => context.read<DashboardCubit>().refresh(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Text(
              'Завершённые заказы · Московское время',
              style: TextStyle(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 4 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final period in DashboardCubit.cardPeriods)
                      SizedBox(
                        width: width,
                        child: _card(
                          context,
                          period,
                          state.cards[period]!.summary,
                          period == state.period,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final period in DashboardPeriod.values)
                  ChoiceChip(
                    label: Text(period.label),
                    selected: state.period == period,
                    onSelected: (_) {
                      if (period == DashboardPeriod.custom) {
                        _choose(context, state);
                      } else {
                        context.read<DashboardCubit>().select(period);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_date(revenue.from.toUtc().add(const Duration(hours: 3)))} — ${_date(revenue.to.toUtc().add(const Duration(hours: 3)))} · МСК',
            ),
            if (revenue.summary.ordersCount == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('За период нет завершённых заказов'),
              ),
            const SizedBox(height: 20),
            _table(
              context,
              'По дням',
              const ['Дата', 'Заказов', 'Выручка', 'Средний чек'],
              [
                for (final day in revenue.byDay)
                  [
                    _date(day.date),
                    '${day.count}',
                    _money(day.total),
                    _money(day.averageCheck),
                  ],
              ],
              numericFrom: 1,
            ),
            const SizedBox(height: 20),
            _table(
              context,
              'Топ-5 блюд',
              const ['Название', 'Кол-во', 'Выручка'],
              [
                for (final item in revenue.topItems)
                  [item.name, '${item.quantity}', _money(item.revenue)],
              ],
              numericFrom: 1,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Выручка блюд — до общей бонусной скидки заказа.',
                style: TextStyle(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _card(
    BuildContext context,
    DashboardPeriod period,
    RevenueTotals totals,
    bool active,
  ) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: active ? AppColors.terracotta : AppColors.outline,
        width: active ? 2 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.read<DashboardCubit>().select(period),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(period.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _money(totals.total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.terracotta,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Заказов: ${totals.ordersCount}'),
            Text('Средний: ${_money(totals.averageCheck)}'),
          ],
        ),
      ),
    ),
  );

  Widget _table(
    BuildContext context,
    String title,
    List<String> headers,
    List<List<String>> rows, {
    required int numericFrom,
  }) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('Нет данных')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  for (var i = 0; i < headers.length; i++)
                    DataColumn(
                      label: Text(headers[i]),
                      numeric: i >= numericFrom,
                    ),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [for (final value in row) DataCell(Text(value))],
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
