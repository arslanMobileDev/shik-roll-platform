import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../bloc/kds_orders_bloc.dart';
import '../bloc/kds_orders_event.dart';
import '../bloc/kds_orders_state.dart';
import '../data/kds_order_models.dart';
import 'widgets/kds_status_column.dart';

/// UI-804 — kitchen display board.
///
/// Three status columns («В очереди» → «Готовятся» → «Готовы»), auto-refresh
/// via [KdsOrdersBloc] polling, manual refresh in the header and audio/visual
/// feedback when new orders arrive.
class KdsScreen extends StatelessWidget {
  const KdsScreen({super.key, this.onNewOrders, this.now});

  /// Override for the new-order audio alert (tests inject a spy; production
  /// plays the system alert sound).
  final void Function(List<KdsOrder> freshOrders)? onNewOrders;

  /// Fixed clock for deterministic delay timers in tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<KdsOrdersBloc, KdsOrdersState>(
          listenWhen: (previous, current) =>
              current.freshOrderIds.isNotEmpty &&
              previous.freshOrderIds != current.freshOrderIds,
          listener: _onFreshOrders,
        ),
        BlocListener<KdsOrdersBloc, KdsOrdersState>(
          listenWhen: (previous, current) =>
              current is KdsOrdersLoaded &&
              current.actionError != null &&
              (previous is! KdsOrdersLoaded ||
                  previous.actionError != current.actionError),
          listener: (context, state) {
            final message = (state as KdsOrdersLoaded).actionError;
            if (message == null) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.error,
                  content: Text(message),
                ),
              );
          },
        ),
      ],
      child: _buildScaffold(context),
    );
  }

  void _onFreshOrders(BuildContext context, KdsOrdersState state) {
    final fresh =
        state.orders
            ?.where((o) => state.freshOrderIds.contains(o.id))
            .toList() ??
        const <KdsOrder>[];
    if (fresh.isEmpty) return;

    final alerter = onNewOrders;
    if (alerter != null) {
      alerter(fresh);
    } else {
      SystemSound.play(SystemSoundType.alert);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.info,
          content: Text(
            'Новый заказ: ${fresh.map((o) => '#${o.orderNumber}').join(', ')}',
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: AppColors.onInfo,
            onPressed: () => context.read<KdsOrdersBloc>().add(
              const KdsOrdersNewOrdersAcknowledged(),
            ),
          ),
        ),
      );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кухня — SHIK ROLL'),
        actions: [
          BlocSelector<KdsOrdersBloc, KdsOrdersState, DateTime?>(
            selector: (state) =>
                state is KdsOrdersLoaded ? state.lastUpdatedAt : null,
            builder: (context, updatedAt) {
              if (updatedAt == null) return const SizedBox.shrink();
              final hh = updatedAt.hour.toString().padLeft(2, '0');
              final mm = updatedAt.minute.toString().padLeft(2, '0');
              final ss = updatedAt.second.toString().padLeft(2, '0');
              return Center(
                child: Text(
                  'Обновлено $hh:$mm:$ss',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.gray600),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('kds-refresh-button'),
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<KdsOrdersBloc>().add(const KdsOrdersRefreshed()),
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: BlocBuilder<KdsOrdersBloc, KdsOrdersState>(
        builder: (context, state) => switch (state) {
          KdsOrdersLoading() => const LoadingView(label: 'Загружаем заказы…'),
          KdsOrdersError(:final message) => ErrorView(
            title: 'Нет связи с сервером',
            message: message,
            onRetry: () =>
                context.read<KdsOrdersBloc>().add(const KdsOrdersRefreshed()),
          ),
          _ => _KdsBoard(state: state, now: now),
        },
      ),
    );
  }
}

class _KdsBoard extends StatelessWidget {
  const _KdsBoard({required this.state, this.now});

  final KdsOrdersState state;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final orders = state.orders ?? const <KdsOrder>[];
    final queued = orders.where((o) => o.isQueued).toList();
    final cooking = orders
        .where((o) => o.status == KdsOrderStatus.cooking)
        .toList();
    final ready = orders
        .where((o) => o.status == KdsOrderStatus.ready)
        .toList();
    final pendingOrderId = switch (state) {
      KdsOrdersActionInProgress(:final pendingOrderId) => pendingOrderId,
      _ => null,
    };

    final columns = <(String, Color, List<KdsOrder>)>[
      ('В очереди', AppColors.info, queued),
      ('Готовятся', AppColors.warning, cooking),
      ('Готовы', AppColors.success, ready),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile landscape / narrow windows: tabs; tablet 1024x768 and web:
        // all three columns side by side.
        if (AppBreakpoints.isMobile(constraints.maxWidth)) {
          return DefaultTabController(
            length: columns.length,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    for (final (title, _, list) in columns)
                      Tab(text: '$title (${list.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final (title, accent, list) in columns)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.s8),
                          child: KdsStatusColumn(
                            title: title,
                            accent: accent,
                            orders: list,
                            freshOrderIds: state.freshOrderIds,
                            pendingOrderId: pendingOrderId,
                            now: now,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (title, accent, list) in columns) ...[
                Expanded(
                  child: KdsStatusColumn(
                    title: title,
                    accent: accent,
                    orders: list,
                    freshOrderIds: state.freshOrderIds,
                    pendingOrderId: pendingOrderId,
                    now: now,
                  ),
                ),
                if (title != columns.last.$1)
                  const SizedBox(width: AppSpacing.s8),
              ],
            ],
          ),
        );
      },
    );
  }
}
