import 'package:equatable/equatable.dart';

/// Delivery lifecycle status (matches backend contract strings).
enum OrderStatus {
  ready('READY'),
  delivering('DELIVERING'),
  completed('COMPLETED');

  const OrderStatus(this.wireName);
  final String wireName;

  static OrderStatus fromWire(String value) => OrderStatus.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => OrderStatus.ready,
      );
}

enum PaymentMethod {
  cash('Наличные'),
  onlinePaid('Онлайн оплачено');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod fromWire(String? value) =>
      value == 'onlinePaid' ? PaymentMethod.onlinePaid : PaymentMethod.cash;
}

/// Delivery address details for the courier card.
class DeliveryAddress extends Equatable {
  const DeliveryAddress({
    required this.street,
    this.apartment,
    this.entrance,
    this.floor,
    this.intercom,
    this.lat,
    this.lon,
  });

  final String street;
  final String? apartment;
  final String? entrance;
  final String? floor;
  final String? intercom;
  final double? lat;
  final double? lon;

  /// «кв. 12 · под. 3 · эт. 5 · домофон 127»
  String get detailsLine {
    final parts = <String>[
      if (apartment?.isNotEmpty ?? false) 'кв. $apartment',
      if (entrance?.isNotEmpty ?? false) 'под. $entrance',
      if (floor?.isNotEmpty ?? false) 'эт. $floor',
      if (intercom?.isNotEmpty ?? false) 'домофон $intercom',
    ];
    return parts.join(' · ');
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        street: json['street'] as String? ?? '',
        apartment: json['apartment'] as String?,
        entrance: json['entrance'] as String?,
        floor: json['floor'] as String?,
        intercom: json['intercom'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'street': street,
        if (apartment != null) 'apartment': apartment,
        if (entrance != null) 'entrance': entrance,
        if (floor != null) 'floor': floor,
        if (intercom != null) 'intercom': intercom,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
      };

  @override
  List<Object?> get props =>
      [street, apartment, entrance, floor, intercom, lat, lon];
}

/// Active delivery order as shown to the courier.
class CourierOrder extends Equatable {
  const CourierOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.totalRubles,
    required this.paymentMethod,
    required this.address,
    required this.clientPhone,
    required this.branchId,
    this.clientComment,
    this.courierId,
  });

  final String id;

  /// Human-facing order number, e.g. «A-1024».
  final String number;
  final OrderStatus status;
  final int totalRubles;
  final PaymentMethod paymentMethod;
  final DeliveryAddress address;
  final String clientPhone;
  final String? clientComment;
  final String branchId;
  final String? courierId;

  /// «1 250 ₽»
  String get formattedTotal {
    final digits = totalRubles.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
    }
    return '${buffer.toString().trim()} ₽';
  }

  CourierOrder copyWith({OrderStatus? status, String? courierId}) =>
      CourierOrder(
        id: id,
        number: number,
        status: status ?? this.status,
        totalRubles: totalRubles,
        paymentMethod: paymentMethod,
        address: address,
        clientPhone: clientPhone,
        clientComment: clientComment,
        branchId: branchId,
        courierId: courierId ?? this.courierId,
      );

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    final rawAddress = json['address'];
    return CourierOrder(
      id: json['id'] as String,
      number: json['number'] as String? ?? json['id'] as String,
      status: OrderStatus.fromWire(json['status'] as String? ?? 'READY'),
      totalRubles:
          (json['totalRubles'] as num? ?? json['total'] as num? ?? 0).toInt(),
      paymentMethod: PaymentMethod.fromWire(json['paymentMethod'] as String?),
      address: rawAddress is Map<String, dynamic>
          ? DeliveryAddress.fromJson(rawAddress)
          : DeliveryAddress(street: rawAddress as String? ?? ''),
      clientPhone: json['clientPhone'] as String? ?? '',
      clientComment: json['clientComment'] as String?,
      branchId: json['branchId'] as String? ?? '',
      courierId: json['courierId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        status,
        totalRubles,
        paymentMethod,
        address,
        clientPhone,
        clientComment,
        branchId,
        courierId,
      ];
}
