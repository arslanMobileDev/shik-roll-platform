import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef SystemAlertPlayer = Future<void> Function();

/// New-order system alert for the kitchen board.
///
/// Bursts are coalesced into one alert and the station mute toggle is kept in
/// this service so it survives board widget rebuilds.
abstract interface class KitchenAlertService {
  ValueListenable<bool> get mutedListenable;
  bool get muted;
  void setMuted(bool value);
  ValueListenable<bool> get needsUnlockListenable;
  Future<void> unlock();
  void notifyNewOrders(int count);
  Future<void> dispose();
}

final class SystemKitchenAlertService implements KitchenAlertService {
  SystemKitchenAlertService({
    SystemAlertPlayer? player,
    this.coalesceWindow = const Duration(milliseconds: 500),
  }) : _player = player ?? _playSystemAlert;

  final SystemAlertPlayer _player;
  final Duration coalesceWindow;
  final ValueNotifier<bool> _muted = ValueNotifier(false);
  final ValueNotifier<bool> _needsUnlock = ValueNotifier(false);
  Timer? _coalesceTimer;

  static Future<void> _playSystemAlert() =>
      SystemSound.play(SystemSoundType.alert);

  @override
  ValueListenable<bool> get mutedListenable => _muted;

  @override
  bool get muted => _muted.value;

  @override
  void setMuted(bool value) => _muted.value = value;

  @override
  ValueListenable<bool> get needsUnlockListenable => _needsUnlock;

  @override
  void notifyNewOrders(int count) {
    if (count <= 0 || _muted.value) return;
    _coalesceTimer?.cancel();
    _coalesceTimer = Timer(coalesceWindow, _play);
  }

  Future<void> _play() async {
    if (_muted.value) return;
    try {
      await _player();
    } on Object {
      // The visual order highlight remains available if the platform has no
      // system alert implementation or audio output.
    }
  }

  @override
  Future<void> unlock() async {
    // SystemSound does not own a browser audio context and needs no priming.
    _needsUnlock.value = false;
  }

  @override
  Future<void> dispose() async {
    _coalesceTimer?.cancel();
    _muted.dispose();
    _needsUnlock.dispose();
  }
}
