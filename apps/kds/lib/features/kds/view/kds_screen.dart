import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/audio/kitchen_alert_service.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/bloc/kitchen_auth_cubit.dart';
import '../../shift/view/widgets/cook_shift_header.dart';
import '../bloc/kds_orders_bloc.dart';
import '../bloc/kds_orders_event.dart';
import '../bloc/kds_orders_state.dart';
import '../data/kds_order_models.dart';
import 'widgets/kds_status_column.dart';

/// UI-804 / ADR-1618 — kitchen display board.
///
/// Three status columns («Новые» → «Готовятся» → «Готовы»), live updates over
/// the kitchen SSE stream with a visible connection indicator, audio/visual
/// feedback for newly CONFIRMED orders and kitchen-owned transitions only
/// (handout belongs to POS/courier).
class KdsScreen extends StatelessWidget {
  const KdsScreen({super.key, this.alertService, this.now});

  /// New-order audio alert (tests inject a spy; production wires the
  /// audioplayers-backed service from the app graph).
  final KitchenAlertService? alertService;

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

    alertService?.notifyNewOrders(fresh.length);

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
          const CookShiftHeader(),
          const SizedBox(width: AppSpacing.s12),
          if (alertService case final alerts?) ...[
            _SoundUnlockButton(alertService: alerts),
            _MuteToggle(alertService: alerts),
          ],
          const _ConnectionIndicator(),
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
          IconButton(
            key: const Key('kds-logout-button'),
            tooltip: 'Выйти из терминала',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<KitchenAuthCubit>().logout(),
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

/// Live/polling/offline transport indicator (ADR-1618 recovery contract).
class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<KdsOrdersBloc, KdsOrdersState, KdsConnectionStatus>(
      selector: (state) => state.connection,
      builder: (context, connection) {
        final (icon, color, tooltip) = switch (connection) {
          KdsConnectionStatus.live => (
            Icons.wifi,
            AppColors.success,
            'Онлайн: поток обновлений активен',
          ),
          KdsConnectionStatus.connecting => (
            Icons.sync,
            AppColors.warning,
            'Подключаемся к потоку обновлений…',
          ),
          KdsConnectionStatus.polling => (
            Icons.sync_problem,
            AppColors.warning,
            'Поток недоступен: обновление каждые 15 секунд',
          ),
        };
        return Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Icon(
              key: Key('kds-connection-$connection'),
              icon,
              size: 20,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

/// Station sound toggle with a visible mute state.
class _MuteToggle extends StatelessWidget {
  const _MuteToggle({required this.alertService});

  final KitchenAlertService alertService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: alertService.mutedListenable,
      builder: (context, muted, _) => IconButton(
        key: const Key('kds-mute-toggle'),
        tooltip: muted ? 'Включить звук заказов' : 'Выключить звук заказов',
        icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
        color: muted ? AppColors.gray500 : null,
        onPressed: () => alertService.setMuted(!muted),
      ),
    );
  }
}

/// Web autoplay unlock: visible only until a gesture primes the audio
/// pipeline (ADR-1618 sound contract).
class _SoundUnlockButton extends StatelessWidget {
  const _SoundUnlockButton({required this.alertService});

  final KitchenAlertService alertService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: alertService.needsUnlockListenable,
      builder: (context, needsUnlock, _) {
        if (!needsUnlock) return const SizedBox.shrink();
        return TextButton.icon(
          key: const Key('kds-sound-unlock'),
          onPressed: alertService.unlock,
          icon: const Icon(Icons.music_off, size: 18),
          label: const Text('Включить звук'),
        );
      },
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
    final fresh = orders
        .where((o) => o.status == KdsOrderStatus.confirmed)
        .toList();
    final cooking = orders
        .where((o) => o.status == KdsOrderStatus.cooking)
        .toList();
    final ready = orders
        .where((o) => o.status == KdsOrderStatus.ready)
        .toList();

    final columns = <(String, Color, List<KdsOrder>)>[
      ('Новые', AppColors.info, fresh),
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
                            mutatingOrderIds: state.mutatingOrderIds,
                            clockOffset: state.serverClockOffset,
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
                    mutatingOrderIds: state.mutatingOrderIds,
                    clockOffset: state.serverClockOffset,
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
