import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/halal_badge.dart';
import '../../../core/theme/shik_colors.dart';
import '../../../data/models/courier_order.dart';
import '../../../data/models/courier_session.dart';
import '../../../data/repositories/courier_repository.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../../location/bloc/location_tracking_cubit.dart';
import '../../location/bloc/location_tracking_state.dart';
import '../../location/data/courier_location_repository.dart';
import '../../location/data/courier_location_source.dart';
import '../bloc/orders_cubit.dart';
import '../bloc/orders_state.dart';
import '../widgets/courier_order_card.dart';
import 'delivery_detail_screen.dart';

/// Экран заказов филиала (ADR-1617): «Доступные» / «Мой активный заказ»,
/// SSE с polling fallback и фоновой геотрекинг собственного ON_WAY заказа.
class CourierOrdersScreen extends StatelessWidget {
  const CourierOrdersScreen({
    super.key,
    required this.session,
    this.locationSource,
  });

  final CourierSession session;

  /// Источник геолокации; в тестах подменяется фейком, по умолчанию —
  /// geolocator (Android Foreground Service / iOS Background Location).
  final CourierLocationSource? locationSource;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => OrdersCubit(
            repository: context.read<CourierRepository>(),
            session: session,
          )..start(),
        ),
        BlocProvider(
          create: (context) => LocationTrackingCubit(
            source: locationSource ?? GeolocatorLocationSource(),
            repository: context.read<CourierLocationRepository>(),
          ),
        ),
      ],
      child: const _CourierOrdersView(),
    );
  }
}

class _CourierOrdersView extends StatefulWidget {
  const _CourierOrdersView();

  @override
  State<_CourierOrdersView> createState() => _CourierOrdersViewState();
}

class _CourierOrdersViewState extends State<_CourierOrdersView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Polling работает только в foreground; каждый resume — мгновенный
    // refresh снапшота (ADR-1617).
    context.read<OrdersCubit>().setForeground(
      state == AppLifecycleState.resumed,
    );
  }

  static String? _onWayOrderId(OrdersState state) =>
      state is OrdersLoaded ? state.myOnWayOrder?.id : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHIK ROLL Курьер', style: theme.textTheme.titleMedium),
            BlocBuilder<OrdersCubit, OrdersState>(
              builder: (context, state) => Text(
                state is OrdersLoaded ? 'Активных: ${state.orders.length}' : '',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: HalalBadge(compact: true),
          ),
        ],
      ),
      drawer: const _CourierDrawer(),
      body: MultiBlocListener(
        listeners: [
          // Смена собственного ON_WAY заказа включает/выключает геотрекинг.
          BlocListener<OrdersCubit, OrdersState>(
            listenWhen: (previous, next) =>
                _onWayOrderId(previous) != _onWayOrderId(next),
            listener: (context, state) {
              final order = state is OrdersLoaded ? state.myOnWayOrder : null;
              context.read<LocationTrackingCubit>().syncActiveOrder(order);
            },
          ),
          BlocListener<OrdersCubit, OrdersState>(
            listener: (context, state) {
              if (state is OrdersFailure) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
          ),
        ],
        child: BlocBuilder<OrdersCubit, OrdersState>(
          builder: (context, state) {
            return switch (state) {
              OrdersLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              OrdersFailure(message: final message) => _ErrorState(
                message: message,
                onRetry: () => context.read<OrdersCubit>().refresh(),
              ),
              OrdersLoaded() => _LoadedBody(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.state});

  final OrdersLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<OrdersTab>(
            key: const Key('orders_tab_switcher'),
            segments: [
              ButtonSegment(
                value: OrdersTab.available,
                label: Text('Доступные (${state.availableOrders.length})'),
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              const ButtonSegment(
                value: OrdersTab.mine,
                label: Text('Мой активный заказ'),
                icon: Icon(Icons.pedal_bike),
              ),
            ],
            selected: {state.tab},
            onSelectionChanged: (selection) => cubit.selectTab(selection.first),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              _RealtimeChip(),
              SizedBox(width: 8),
              Expanded(child: _LocationWarning()),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.refresh,
            child: _OrdersList(state: state),
          ),
        ),
      ],
    );
  }
}

/// Индикатор realtime-подключения: SSE live / переподключение / polling.
class _RealtimeChip extends StatelessWidget {
  const _RealtimeChip();

  @override
  Widget build(BuildContext context) {
    final realtime = context.select(
      (OrdersCubit cubit) => cubit.state is OrdersLoaded
          ? (cubit.state as OrdersLoaded).realtime
          : RealtimeConnectionState.connecting,
    );

    final (icon, label, color) = switch (realtime) {
      RealtimeConnectionState.live => (
        Icons.wifi,
        'Онлайн',
        ShikColors.success,
      ),
      RealtimeConnectionState.connecting => (
        Icons.sync,
        'Подключение…',
        ShikColors.warning,
      ),
      RealtimeConnectionState.polling => (
        Icons.wifi_off,
        'Опрос 30 с',
        ShikColors.warning,
      ),
    };

    return Chip(
      key: const Key('realtime_indicator'),
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
    );
  }
}

/// Предупреждения геотрекинга: нет разрешения / сервис выключен /
/// только foreground. Видно, только пока есть проблема.
class _LocationWarning extends StatelessWidget {
  const _LocationWarning();

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (LocationTrackingCubit cubit) => cubit.state.status,
    );

    final String? message;
    final String? actionLabel;
    final VoidCallback? action;
    switch (status) {
      case CourierTrackingStatus.serviceDisabled:
        message = 'Геолокация выключена';
        actionLabel = 'Включить';
        action = () =>
            context.read<LocationTrackingCubit>().openLocationSettings();
      case CourierTrackingStatus.permissionDenied:
        message = 'Нет доступа к геолокации';
        actionLabel = 'Настройки';
        action = () => context.read<LocationTrackingCubit>().openAppSettings();
      case CourierTrackingStatus.trackingForegroundOnly:
        message = 'Геолокация — только в открытом приложении';
        actionLabel = null;
        action = null;
      case CourierTrackingStatus.off:
      case CourierTrackingStatus.requestingPermission:
      case CourierTrackingStatus.tracking:
        message = null;
        actionLabel = null;
        action = null;
    }
    if (message == null) return const SizedBox.shrink();

    return Container(
      key: const Key('location_warning'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ShikColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ShikColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_disabled,
            size: 16,
            color: ShikColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: ShikColors.warning),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              key: const Key('location_warning_action'),
              onTap: action,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ShikColors.warning,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.state});

  final OrdersLoaded state;

  void _openDetails(BuildContext context, String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: context.read<OrdersCubit>(),
          child: DeliveryDetailScreen(orderId: orderId),
        ),
      ),
    );
  }

  Future<void> _confirmComplete(
    BuildContext context,
    String orderId,
    String number,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Заказ #$number доставлен?'),
        content: const Text('Подтвердите передачу заказа клиенту.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Да, доставлено'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<OrdersCubit>().completeDelivery(orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();
    final orders = state.ordersFor(state.tab);
    final isAvailableTab = state.tab == OrdersTab.available;

    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            isAvailableTab ? Icons.shopping_bag_outlined : Icons.pedal_bike,
            size: 56,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 12),
          Text(
            isAvailableTab
                ? 'Нет доступных заказов филиала'
                : 'Нет активного заказа',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isOwn = order.courierId == state.courierId;
        return CourierOrderCard(
          order: order,
          updating: state.mutatingOrderId == order.id,
          onTap: () => _openDetails(context, order.id),
          onClaim: order.status == OrderStatus.ready && order.courierId == null
              ? () => cubit.claim(order.id)
              : null,
          onStart: order.status == OrderStatus.ready && isOwn
              ? () => cubit.startDelivery(order.id)
              : null,
          onComplete: order.status == OrderStatus.onWay && isOwn
              ? () => _confirmComplete(context, order.id, order.number)
              : null,
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}

class _CourierDrawer extends StatelessWidget {
  const _CourierDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: HalalBadge()),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                key: const Key('logout_button'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<AuthCubit>().logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
