import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/state_views.dart';
import '../../shift/view/widgets/cook_shift_header.dart';
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
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key, this.onNewOrders, this.now});

  /// Override for the new-order audio alert (tests inject a spy; production
  /// plays the system alert sound).
  final void Function(List<KdsOrder> freshOrders)? onNewOrders;

  /// Fixed clock for deterministic delay timers in tests.
  final DateTime? now;

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  static const _alertDebounce = Duration(milliseconds: 500);

  final Map<String, KdsOrder> _pendingAlertOrders = {};
  Timer? _alertTimer;
  bool _soundEnabled = true;

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

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

    for (final order in fresh) {
      _pendingAlertOrders[order.id] = order;
    }
    _alertTimer?.cancel();
    _alertTimer = Timer(_alertDebounce, () => _showNewOrdersAlert(context));
  }

  void _showNewOrdersAlert(BuildContext context) {
    if (!mounted || _pendingAlertOrders.isEmpty) return;
    final fresh = List<KdsOrder>.unmodifiable(_pendingAlertOrders.values);
    _pendingAlertOrders.clear();

    if (_soundEnabled) {
      final alerter = widget.onNewOrders;
      if (alerter != null) {
        alerter(fresh);
      } else {
        SystemSound.play(SystemSoundType.alert);
      }
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
          const CookShiftHeader(),
          const SizedBox(width: AppSpacing.s12),
          BlocSelector<KdsOrdersBloc, KdsOrdersState, KdsConnectionStatus>(
            selector: (state) => state.connectionStatus,
            builder: (context, status) => _ConnectionIndicator(status: status),
          ),
          const SizedBox(width: AppSpacing.s4),
          BlocSelector<KdsOrdersBloc, KdsOrdersState, DateTime?>(
            selector: (state) =>
                state is KdsOrdersLoaded ? state.lastUpdatedAt : null,
            builder: (context, updatedAt) {
              if (updatedAt == null) return const SizedBox.shrink();
              final hh = updatedAt.hour.toString().padLeft(2, '0');
              final mm = updatedAt.minute.toString().padLeft(2, '0');
              final ss = updatedAt.second.toString().padLeft(2, '0');
              return Tooltip(
                message: 'Обновлено $hh:$mm:$ss',
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                  child: Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppColors.gray600,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('kds-sound-toggle'),
            tooltip: _soundEnabled ? 'Выключить звук' : 'Включить звук',
            icon: Icon(
              _soundEnabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
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
          _ => _KdsBoard(state: state, now: widget.now),
        },
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.status});

  final KdsConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      KdsConnectionStatus.online => ('Онлайн', AppColors.success),
      KdsConnectionStatus.connecting => ('Подключение…', AppColors.warning),
      KdsConnectionStatus.reconnecting => (
        'Переподключение…',
        AppColors.warning,
      ),
      KdsConnectionStatus.offline => ('Нет сети', AppColors.error),
    };

    return Tooltip(
      message: label,
      child: Semantics(
        key: const Key('kds-connection-indicator'),
        label: 'Статус соединения: $label',
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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
