import 'package:equatable/equatable.dart';

/// Location tracking lifecycle (ADR-1617): active only for the courier's own
/// ON_WAY order, stopped immediately on COMPLETED / logout / lost ownership.
enum CourierTrackingStatus {
  /// No own ON_WAY order — tracking off.
  off,

  /// Permission flow in progress.
  requestingPermission,

  /// Tracking with background capability.
  tracking,

  /// «While in Use» only — delivery continues with foreground-only tracking
  /// and a visible warning.
  trackingForegroundOnly,

  /// Location services off on the device.
  serviceDisabled,

  /// Permission denied / permanently denied — offer system settings.
  permissionDenied,
}

class LocationTrackingState extends Equatable {
  const LocationTrackingState({
    this.status = CourierTrackingStatus.off,
    this.activeOrderId,
    this.lastSentAt,
  });

  final CourierTrackingStatus status;

  /// Order currently being tracked (own ON_WAY).
  final String? activeOrderId;

  /// Last successfully sent fix time (for UI/debug).
  final DateTime? lastSentAt;

  bool get isTracking =>
      status == CourierTrackingStatus.tracking ||
      status == CourierTrackingStatus.trackingForegroundOnly;

  LocationTrackingState copyWith({
    CourierTrackingStatus? status,
    String? Function()? activeOrderId,
    DateTime? Function()? lastSentAt,
  }) => LocationTrackingState(
    status: status ?? this.status,
    activeOrderId: activeOrderId != null ? activeOrderId() : this.activeOrderId,
    lastSentAt: lastSentAt != null ? lastSentAt() : this.lastSentAt,
  );

  @override
  List<Object?> get props => [status, activeOrderId, lastSentAt];
}
