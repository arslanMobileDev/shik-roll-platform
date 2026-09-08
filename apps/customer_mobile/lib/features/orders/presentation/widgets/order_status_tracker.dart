import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../profile/bloc/user_settings_cubit.dart';
import '../../../profile/domain/delivery_vehicle.dart';
import '../../domain/order_timeline.dart';

/// Карточка трекера заказа: статус-чип, расчётное время доставки,
/// анимированная шкала прогресса и вертикальный список шагов timeline
/// (проекция ADR-1615). Отменённый заказ ([status] == null) показывается
/// без процента прогресса.
class OrderStatusTracker extends StatefulWidget {
  const OrderStatusTracker({
    super.key,
    required this.orderNumber,
    required this.status,
    required this.progressPercent,
    this.estimatedDeliveryAt,
    this.updatedAt,
  });

  final String orderNumber;

  /// Текущий шаг timeline; `null` — заказ отменён.
  final OrderTimelineStatus? status;

  /// Процент прогресса (5/15/40/55/75/100 по ADR-1615).
  final int progressPercent;

  /// Расчётное время доставки; `null` — блок ETA показывает плейсхолдеры.
  final DateTime? estimatedDeliveryAt;

  /// Время последнего перехода (подпись у активного шага).
  final DateTime? updatedAt;

  @override
  State<OrderStatusTracker> createState() => _OrderStatusTrackerState();
}

class _OrderStatusTrackerState extends State<OrderStatusTracker> {
  bool _didPrecacheVehicles = false;

  static const double _vehicleImageCacheSize = 256;
  static const _brandOrange = Color(0xFFFF5200);
  static const _cancelRed = Color(0xFFE53935);

  bool get _isCancelled => widget.status == null;

  int get _currentStep => widget.status?.index ?? -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheVehicles) return;
    _didPrecacheVehicles = true;
    // Прогреваем кэш всех иконок транспорта после первого кадра,
    // чтобы переключение в селекторе было мгновенным и без джанка.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final v in DeliveryVehicle.values) {
        final provider = v.imageUrl.startsWith('assets/')
            ? ResizeImage(
                AssetImage(v.imageUrl),
                width: _vehicleImageCacheSize.toInt(),
                height: _vehicleImageCacheSize.toInt(),
              )
            : ResizeImage(
                NetworkImage(v.imageUrl),
                width: _vehicleImageCacheSize.toInt(),
                height: _vehicleImageCacheSize.toInt(),
              );
        // Ошибку прогрева глотаем: промах кэша не критичен —
        // Image отрендерит errorBuilder с эмодзи-фолбэком.
        precacheImage(provider, context).onError((_, _) {});
      }
    });
  }

  Widget _buildVehicleImage(String url, String fallbackEmoji, double size) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: _vehicleImageCacheSize.toInt(),
        cacheHeight: _vehicleImageCacheSize.toInt(),
        gaplessPlayback: true,
        errorBuilder: (_, e, s) =>
            Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.7)),
      );
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: _vehicleImageCacheSize.toInt(),
      cacheHeight: _vehicleImageCacheSize.toInt(),
      gaplessPlayback: true,
      errorBuilder: (_, e, s) =>
          Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Глобальный «скин» доставки из настроек гостя (ADR-1616); до завершения
    // UserSettingsCubit.load() действует дефолт yellowScooter.
    final vehicle = context.select<UserSettingsCubit, DeliveryVehicle>(
      (cubit) => cubit.state.selectedCourierVehicle,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildEtaCard(vehicle),
          if (!_isCancelled) ...[
            const SizedBox(height: 20),
            _buildProgressBar(),
          ],
          const SizedBox(height: 20),
          ..._buildSteps(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final chipColor = _isCancelled ? _cancelRed : _brandOrange;
    final chipLabel = _isCancelled ? 'Отменён' : widget.status!.label;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ВАШ ЗАКАЗ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A8A8E),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '#${widget.orderNumber}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            chipLabel,
            style: TextStyle(
              color: chipColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Блок транспорта + расчётного времени доставки. Для отменённого заказа —
  /// нейтральное уведомление вместо ETA.
  Widget _buildEtaCard(DeliveryVehicle vehicle) {
    if (_isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: _cancelRed, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Заказ отменён. Если списались деньги — они вернутся автоматически.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A8A8E),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final eta = widget.estimatedDeliveryAt?.toLocal();
    final remainingMinutes = eta?.difference(DateTime.now()).inMinutes.clamp(
      0,
      999,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildVehicleImage(vehicle.imageUrl, vehicle.fallbackEmoji, 46),
          const SizedBox(width: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                remainingMinutes == null ? '—' : '$remainingMinutes',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _brandOrange,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'мин',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _brandOrange,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Доставка к',
                style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8E)),
              ),
              const SizedBox(height: 2),
              Text(
                eta == null ? '—' : DateFormat('HH:mm').format(eta),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Шкала прогресса: плавно догоняет новый процент при каждом событии.
  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          key: const ValueKey('order-progress-bar'),
          tween: Tween<double>(
            begin: 0,
            end: (widget.progressPercent / 100).clamp(0.0, 1.0),
          ),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F3F5),
                valueColor: const AlwaysStoppedAnimation(_brandOrange),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Шаг ${_currentStep + 1} из ${OrderTimelineStatus.values.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8A8A8E),
              ),
            ),
            Text(
              '${widget.progressPercent}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _brandOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildSteps() {
    final updatedAt = widget.updatedAt?.toLocal();
    return [
      for (var i = 0; i < OrderTimelineStatus.values.length; i++)
        _buildStepRow(
          title: OrderTimelineStatus.values[i].stepTitle,
          // Точное время знаем только у текущего шага (по событию).
          time: i == _currentStep && updatedAt != null
              ? DateFormat('HH:mm').format(updatedAt)
              : '--',
          isPassed: !_isCancelled && i <= _currentStep,
          isActive: !_isCancelled && i == _currentStep,
          isLast: i == OrderTimelineStatus.values.length - 1,
        ),
    ];
  }

  Widget _buildStepRow({
    required String title,
    required String time,
    required bool isPassed,
    required bool isActive,
    bool isLast = false,
  }) {
    Color iconColor;
    Widget iconWidget;

    if (isActive) {
      iconColor = _brandOrange;
      iconWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 3),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
        ),
      );
    } else if (isPassed) {
      iconColor = _brandOrange;
      iconWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    } else {
      iconColor = const Color(0xFFD1D1D6);
      iconWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: iconColor, width: 2),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive || isPassed
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isActive || isPassed
                    ? Colors.black
                    : const Color(0xFF8A8A8E),
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? _brandOrange : const Color(0xFF8A8A8E),
            ),
          ),
        ],
      ),
    );
  }
}
