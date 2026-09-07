import 'package:flutter/material.dart';

enum OrderStatus {
  confirmed,
  cooking,
  delivering,
  completed;

  static OrderStatus fromDynamic(dynamic val) {
    if (val is OrderStatus) return val;
    final s = (val ?? '').toString().toUpperCase();
    if (s.contains('COOK') || s.contains('ГОТОВ')) return OrderStatus.cooking;
    if (s.contains('DELIVER') || s.contains('WAY') || s.contains('ПУТИ')) return OrderStatus.delivering;
    if (s.contains('COMPLET') || s.contains('DONE') || s.contains('ДОСТАВ')) return OrderStatus.completed;
    return OrderStatus.confirmed;
  }
}

enum DeliveryVehicle {
  yellowScooter('Жёлтый скутер', 'assets/icons/delivery_scooter.png', '🛵'),
  redCar('Красный авто', 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Travel%20and%20places/Automobile.png', '🚗'),
  rocket('Ракета-доставка', 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Travel%20and%20places/Rocket.png', '🚀'),
  skateboard('Скейтборд', 'https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Travel%20and%20places/Skateboard.png', '🛹');

  final String label;
  final String imageUrl;
  final String fallbackEmoji;

  const DeliveryVehicle(this.label, this.imageUrl, this.fallbackEmoji);
}

class OrderStatusTracker extends StatefulWidget {
  final OrderStatus status;
  final String orderNumber;
  final String estimatedDeliveryTime;
  final String? arrivingByTime;
  final int remainingMinutes;
  final String confirmedTime;
  final String cookingTime;
  final String deliveringTime;
  final String completedTime;

  OrderStatusTracker({
    super.key,
    required dynamic status,
    required this.orderNumber,
    String? estimatedDeliveryTime,
    this.arrivingByTime,
    required this.remainingMinutes,
    this.confirmedTime = '19:08',
    this.cookingTime = '19:15',
    this.deliveringTime = '--',
    this.completedTime = '--',
  })  : status = OrderStatus.fromDynamic(status),
        estimatedDeliveryTime = estimatedDeliveryTime ?? arrivingByTime ?? '19:45';

  @override
  State<OrderStatusTracker> createState() => _OrderStatusTrackerState();
}

class _OrderStatusTrackerState extends State<OrderStatusTracker> {
  DeliveryVehicle _selectedVehicle = DeliveryVehicle.yellowScooter;

  Widget _buildVehicleImage(String url, String fallbackEmoji, double size) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, e, s) => Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.7)),
      );
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, e, s) => Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.7)),
    );
  }

  void _showVehiclePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Выберите транспорт курьера',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...DeliveryVehicle.values.map((v) {
                final isSelected = v == _selectedVehicle;
                return ListTile(
                  leading: _buildVehicleImage(v.imageUrl, v.fallbackEmoji, 36),
                  title: Text(v.label),
                  trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFFF5200)) : null,
                  onTap: () {
                    setState(() {
                      _selectedVehicle = v;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  int get currentStep {
    switch (widget.status) {
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.cooking:
        return 2;
      case OrderStatus.delivering:
        return 3;
      case OrderStatus.completed:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
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
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5200).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Готовится',
                  style: TextStyle(
                    color: Color(0xFFFF5200),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showVehiclePicker,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildVehicleImage(_selectedVehicle.imageUrl, _selectedVehicle.fallbackEmoji, 46),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5200),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${widget.remainingMinutes}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF5200),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'мин',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF5200),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A8A8E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.estimatedDeliveryTime,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildStepRow(
            stepNumber: 1,
            title: 'Заказ подтвержден',
            time: widget.confirmedTime,
            isPassed: currentStep >= 1,
            isActive: currentStep == 1,
          ),
          _buildStepRow(
            stepNumber: 2,
            title: 'Шеф готовит',
            time: widget.cookingTime,
            isPassed: currentStep >= 2,
            isActive: currentStep == 2,
          ),
          _buildStepRow(
            stepNumber: 3,
            title: 'Курьер мчит к вам',
            time: widget.deliveringTime,
            isPassed: currentStep >= 3,
            isActive: currentStep == 3,
          ),
          _buildStepRow(
            stepNumber: 4,
            title: 'Приятного аппетита!',
            time: widget.completedTime,
            isPassed: currentStep >= 4,
            isActive: currentStep == 4,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required int stepNumber,
    required String title,
    required String time,
    required bool isPassed,
    required bool isActive,
    bool isLast = false,
  }) {
    Color iconColor;
    Widget iconWidget;

    if (isActive) {
      iconColor = const Color(0xFFFF5200);
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
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else if (isPassed) {
      iconColor = const Color(0xFFFF5200);
      iconWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: iconColor,
          shape: BoxShape.circle,
        ),
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
                fontWeight: isActive || isPassed ? FontWeight.w600 : FontWeight.w400,
                color: isActive || isPassed ? Colors.black : const Color(0xFF8A8A8E),
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFFFF5200) : const Color(0xFF8A8A8E),
            ),
          ),
        ],
      ),
    );
  }
}
