import 'package:flutter/material.dart';
import '../data/cooks_analytics_repository.dart';

import '../bloc/dashboard_state.dart';

class TopCooksCard extends StatefulWidget {
  const TopCooksCard({
    super.key,
    required this.state,
    required this.repository,
  });
  final DashboardState state;
  final CooksAnalyticsRepository repository;
  @override
  State<TopCooksCard> createState() => _TopCooksCardState();
}

class _TopCooksCardState extends State<TopCooksCard> {
  late Future<List<TopCook>> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void didUpdateWidget(TopCooksCard old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) future = load();
  }

  Future<List<TopCook>> load() => widget.repository.load(widget.state);

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Повара (по заказам за период)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FutureBuilder<List<TopCook>>(
            future: future,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (s.hasError) {
                return TextButton(
                  onPressed: () => setState(() => future = load()),
                  child: const Text('Не удалось загрузить · Повторить'),
                );
              }
              final rows = s.data!;
              if (rows.isEmpty) return const Text('Нет данных');
              return Column(
                children: [
                  for (final row in rows)
                    ListTile(
                      title: Text(row.name),
                      subtitle: Text(
                        '${row.ordersCooked} заказов · ${row.averageCookingMinutes} мин',
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
