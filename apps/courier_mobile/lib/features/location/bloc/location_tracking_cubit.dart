import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;

import '../../../data/models/courier_order.dart';
import '../data/courier_location_repository.dart';
import '../data/courier_location_source.dart';
import 'location_tracking_state.dart';

/// Background geotracking for the courier's own ON_WAY order (ADR-1617).
///
/// Lifecycle:
///   own order becomes ON_WAY -> permission gate -> position stream
///   position -> quality check -> throttle/distance gate -> POST /couriers/location
///   COMPLETED / lost ownership / logout -> cancel stream immediately
///
/// Send gate: every 15 s, or on >= 30 m displacement (with a 3 s hard
/// minimum against GPS jitter). Fixes with invalid coordinates or
/// accuracy > 100 m are dropped. Offline keeps only the latest point and
/// drops it after 2 minutes; retries use backoff and never outlive the
/// delivery.
class LocationTrackingCubit extends Cubit<LocationTrackingState> {
  LocationTrackingCubit({
    required this._source,
    required this._repository,
    this._timeGate = const Duration(seconds: 15),
    this._hardMinInterval = const Duration(seconds: 3),
    this._distanceGateMeters = 30,
    this._maxAccuracyMeters = 100,
    this._pendingFixTtl = const Duration(minutes: 2),
  }) : super(const LocationTrackingState());

  final CourierLocationSource _source;
  final CourierLocationRepository _repository;
  final Duration _timeGate;
  final Duration _hardMinInterval;
  final double _distanceGateMeters;
  final double _maxAccuracyMeters;
  final Duration _pendingFixTtl;

  StreamSubscription<CourierPosition>? _positionSub;
  Timer? _retryTimer;
  Duration _retryBackoff = const Duration(seconds: 5);

  CourierPosition? _pendingFix;
  CourierPosition? _lastSentPosition;
  DateTime? _lastSentAt;
  bool _sending = false;

  /// Drives the lifecycle from the orders state: an own ON_WAY order starts
  /// tracking, anything else stops it immediately.
  Future<void> syncActiveOrder(CourierOrder? order) async {
    final activeId = state.activeOrderId;
    if (order == null) {
      if (activeId != null || state.status != CourierTrackingStatus.off) {
        await stop();
      }
      return;
    }
    if (order.id == activeId && state.isTracking) return;
    await _stopStream();
    emit(
      LocationTrackingState(
        status: CourierTrackingStatus.requestingPermission,
        activeOrderId: order.id,
      ),
    );
    await _ensurePermissionAndStart(order.id);
  }

  /// Immediate stop: stream and retries cancelled, state cleared.
  Future<void> stop() async {
    await _stopStream();
    emit(const LocationTrackingState());
  }

  @override
  Future<void> close() async {
    await _stopStream();
    return super.close();
  }

  Future<void> _ensurePermissionAndStart(String orderId) async {
    // 1. Location services must be on.
    if (!await _source.isServiceEnabled()) {
      if (isClosed) return;
      emit(
        state.copyWith(status: CourierTrackingStatus.serviceDisabled),
      );
      return;
    }

    // 2. Request «While in Use» right after the explicit «В пути» action.
    var permission = await _source.checkPermission();
    if (permission == CourierLocationPermission.denied) {
      permission = await _source.requestPermission();
    }
    if (isClosed) return;

    switch (permission) {
      case CourierLocationPermission.denied:
      case CourierLocationPermission.deniedForever:
        // No repeated prompts: the UI offers a jump to system settings.
        emit(state.copyWith(status: CourierTrackingStatus.permissionDenied));
        return;
      case CourierLocationPermission.whileInUse:
        // Delivery continues foreground-only with a visible warning.
        // «Always» is requested separately via system settings.
        _startStream(orderId, background: false);
      case CourierLocationPermission.always:
        _startStream(orderId, background: true);
    }
  }

  void _startStream(String orderId, {required bool background}) {
    emit(
      state.copyWith(
        status: background
            ? CourierTrackingStatus.tracking
            : CourierTrackingStatus.trackingForegroundOnly,
      ),
    );
    _positionSub = _source.positionStream().listen(
      (position) => _onPosition(orderId, position),
      onError: (_) {/* transient GPS errors — stream continues */},
    );
  }

  void _onPosition(String orderId, CourierPosition position) {
    if (!_isValidFix(position)) return;
    final now = DateTime.now();
    final lastAt = _lastSentAt;
    final elapsed = lastAt == null ? null : now.difference(lastAt);

    final timeGatePassed = elapsed == null || elapsed >= _timeGate;
    final distanceGatePassed =
        elapsed != null &&
        elapsed >= _hardMinInterval &&
        _lastSentPosition != null &&
        Geolocator.distanceBetween(
              _lastSentPosition!.latitude,
              _lastSentPosition!.longitude,
              position.latitude,
              position.longitude,
            ) >=
            _distanceGateMeters;

    if (timeGatePassed || distanceGatePassed) {
      _send(orderId, position);
    }
  }

  bool _isValidFix(CourierPosition p) {
    if (!p.latitude.isFinite || !p.longitude.isFinite) return false;
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) return false;
    if (p.latitude == 0 && p.longitude == 0) return false;
    return p.accuracyMeters > 0 && p.accuracyMeters <= _maxAccuracyMeters;
  }

  Future<void> _send(String orderId, CourierPosition position) async {
    if (_sending || isClosed) return;
    if (state.activeOrderId != orderId) return; // delivery already finished
    _sending = true;
    try {
      await _repository.reportLocation(orderId: orderId, position: position);
      _pendingFix = null;
      _retryBackoff = const Duration(seconds: 5);
      _retryTimer?.cancel();
      _lastSentAt = DateTime.now();
      _lastSentPosition = position;
      if (!isClosed) {
        emit(state.copyWith(lastSentAt: () => _lastSentAt));
      }
    } catch (_) {
      // Offline: keep only the latest point; it expires after 2 minutes.
      _pendingFix = position;
      _scheduleRetry(orderId);
    } finally {
      _sending = false;
    }
  }

  void _scheduleRetry(String orderId) {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryBackoff, () {
      _retryBackoff *= 2;
      if (_retryBackoff > const Duration(minutes: 1)) {
        _retryBackoff = const Duration(minutes: 1);
      }
      final pending = _pendingFix;
      if (pending == null || isClosed || state.activeOrderId != orderId) return;
      if (DateTime.now().difference(pending.timestamp) > _pendingFixTtl) {
        _pendingFix = null; // stale fix — dropped, never sent
        return;
      }
      _send(orderId, pending);
    });
  }

  Future<void> _stopStream() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingFix = null;
    _lastSentPosition = null;
    _lastSentAt = null;
    await _positionSub?.cancel();
    _positionSub = null;
  }

  /// Opens the app settings (permission denied flow).
  Future<void> openAppSettings() => _source.openAppSettings();

  /// Opens the OS location settings (service disabled flow).
  Future<void> openLocationSettings() => _source.openLocationSettings();
}
