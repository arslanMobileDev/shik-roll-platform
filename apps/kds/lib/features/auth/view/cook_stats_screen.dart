import 'package:flutter/material.dart';
import '../data/cook_auth_repository.dart';

class CookStatsScreen extends StatefulWidget {
  const CookStatsScreen({
    super.key,
    required this.repository,
    required this.session,
  });
  final CookAuthRepository repository;
  final CookSession session;
  @override
  State<CookStatsScreen> createState() => _CookStatsScreenState();
}

class _CookStatsScreenState extends State<CookStatsScreen> {
  String period = 'today';
  late Future<Map<String, dynamic>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    future = widget.repository.stats(widget.session, period);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Моя статистика')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final p in {
              'today': 'Сегодня',
              'week': 'Неделя',
              'month': 'Месяц',
            }.entries)
              ChoiceChip(
                label: Text(p.value),
                selected: period == p.key,
                onSelected: (_) => setState(() {
                  period = p.key;
                  reload();
                }),
              ),
          ],
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return Column(
                children: [
                  const Text('Не удалось загрузить статистику'),
                  TextButton(
                    onPressed: () => setState(reload),
                    child: const Text('Повторить'),
                  ),
                ],
              );
            }
            final data = s.data!;
            final shift = data['currentShift'] as Map<String, dynamic>;
            final start = DateTime.parse(
              shift['startedAt'] as String,
            ).toUtc().add(const Duration(hours: 3));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Моя смена: ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} МСК · ${shift['durationMinutes']} мин',
                ),
                Text('За смену: ${shift['ordersCooked']} заказов'),
                Text('Среднее за смену: ${shift['averageCookingMinutes']} мин'),
                Text('За период: ${data['ordersCooked']} заказов'),
                Text('Среднее время: ${data['averageCookingMinutes']} мин'),
                const SizedBox(height: 24),
                const Text('Последние 7 дней'),
                for (final row in data['last7Days'] as List)
                  ListTile(
                    title: Text(row['date'] as String),
                    subtitle: Text(
                      '${row['ordersCooked']} заказов · ${row['averageMinutes']} мин',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
