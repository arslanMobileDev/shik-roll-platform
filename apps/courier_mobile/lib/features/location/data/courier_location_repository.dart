import 'package:dio/dio.dart';

import 'courier_location_source.dart';

/// POST /couriers/location transport (ADR-1617).
///
/// The backend accepts a fix (202) only for the courier's own ON_WAY order;
/// identity comes from the JWT attached by CourierAuthInterceptor. Raw
/// coordinates are never logged client- or server-side.
abstract interface class CourierLocationRepository {
  Future<void> reportLocation({
    required String orderId,
    required CourierPosition position,
  });
}

class RemoteCourierLocationRepository implements CourierLocationRepository {
  RemoteCourierLocationRepository({required this._dio});

  final Dio _dio;

  @override
  Future<void> reportLocation({
    required String orderId,
    required CourierPosition position,
  }) {
    return _dio.post<void>(
      '/couriers/location',
      data: {
        'orderId': orderId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracyMeters': position.accuracyMeters,
        'capturedAt': position.timestamp.toUtc().toIso8601String(),
      },
    );
  }
}

/// Offline/demo implementation: accepts everything, records the last fix.
class FakeCourierLocationRepository implements CourierLocationRepository {
  final List<({String orderId, CourierPosition position})> reports = [];

  @override
  Future<void> reportLocation({
    required String orderId,
    required CourierPosition position,
  }) async {
    reports.add((orderId: orderId, position: position));
  }
}
