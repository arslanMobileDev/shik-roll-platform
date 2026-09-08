import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/order_tracking_bloc.dart';
import '../../data/order_tracking_repository.dart';
import '../widgets/order_status_tracker.dart';

/// Экран отслеживания заказа (ADR-1615): живой трекер поверх SSE-стрима
/// с fallback-поллингом, адрес доставки и состав заказа.
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.trackingRepository,
    this.deliveryAddress,
    this.items = const [],
    this.totalPrice,
  });

  final String orderId;
  final String orderNumber;
  final OrderTrackingRepository trackingRepository;

  /// Адрес доставки; блок скрывается для takeaway/неизвестного адреса.
  final String? deliveryAddress;

  /// Состав заказа: `{'name': String, 'count': int, 'price': num}` (RUB).
  final List<Map<String, dynamic>> items;

  /// Итог в рублях; блок итога скрывается, если не передан.
  final num? totalPrice;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OrderTrackingBloc>(
      create: (_) => OrderTrackingBloc(repository: trackingRepository)
        ..add(OrderTrackingStarted(orderId)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Отслеживание заказа',
            style: TextStyle(
              color: Color(0xFF1B1D21),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<OrderTrackingBloc, OrderTrackingState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.loadFailed) {
              return _TrackingError(message: state.errorMessage!);
            }
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 1. Интерактивный статус-трекер
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: OrderStatusTracker(
                      orderNumber: orderNumber,
                      status: state.status,
                      progressPercent: state.progressPercent,
                      estimatedDeliveryAt: state.estimatedDeliveryAt,
                      updatedAt: state.updatedAt,
                    ),
                  ),

                  // 2. Блок адреса доставки
                  if (deliveryAddress != null)
                    _AddressCard(address: deliveryAddress!),

                  // 3. Блок состава заказа
                  if (items.isNotEmpty)
                    _ItemsCard(items: items, totalPrice: totalPrice),

                  // 4. Кнопка связи с поддержкой
                  const _SupportButton(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Color(0xFFB0B0B5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1B1D21)),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) => FilledButton.tonal(
                key: const ValueKey('tracking-retry-button'),
                onPressed: () {
                  final bloc = context.read<OrderTrackingBloc>();
                  bloc.add(const OrderTrackingRefreshed());
                },
                child: const Text('Повторить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF5B00);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECE5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: brandOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Адрес доставки',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1D21),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, this.totalPrice});

  final List<Map<String, dynamic>> items;
  final num? totalPrice;

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF5B00);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Состав заказа',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1D21),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item['count']}x',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${item['price']} ₽',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (totalPrice != null) ...[
            const Divider(height: 24, color: Color(0xFFEEEEEE)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Итого к оплате',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '$totalPrice ₽',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: brandOrange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton();

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFFF5B00);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.headset_mic_rounded, color: brandOrange),
        label: const Text(
          'Связаться с рестораном',
          style: TextStyle(color: brandOrange, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: brandOrange, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
