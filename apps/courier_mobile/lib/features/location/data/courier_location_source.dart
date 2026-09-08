import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Coarse permission level abstraction over geolocator's LocationPermission
/// (keeps the bloc free of plugin types and easy to fake in tests).
enum CourierLocationPermission { denied, deniedForever, whileInUse, always }

/// One device location fix.
class CourierPosition {
  const CourierPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
}

/// Device location capability (ADR-1617). The real implementation delegates
/// to `geolocator`; tests use a fake — no dedicated background service
/// plugin is introduced.
abstract interface class CourierLocationSource {
  Future<bool> isServiceEnabled();
  Future<CourierLocationPermission> checkPermission();
  Future<CourierLocationPermission> requestPermission();
  Stream<CourierPosition> positionStream();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationSource implements CourierLocationSource {
  const GeolocatorLocationSource();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<CourierLocationPermission> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<CourierLocationPermission> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Stream<CourierPosition> positionStream() {
    // Android: foreground location service with a persistent notification
    // only while an ON_WAY delivery is tracked (ADR-1617).
    // iOS: background location updates + the system background indicator.
    final LocationSettings settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 5),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'SHIK ROLL: доставка в пути',
            notificationText:
                'Геолокация передаётся, пока заказ в статусе «В пути»',
            enableWakeLock: false,
          ),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.otherNavigation,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      _ => const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
        ),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => CourierPosition(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyMeters: p.accuracy,
        timestamp: p.timestamp,
      ),
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  CourierLocationPermission _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.denied => CourierLocationPermission.denied,
        LocationPermission.deniedForever =>
          CourierLocationPermission.deniedForever,
        LocationPermission.whileInUse =>
          CourierLocationPermission.whileInUse,
        LocationPermission.always => CourierLocationPermission.always,
        LocationPermission.unableToDetermine =>
          CourierLocationPermission.denied,
      };
}
