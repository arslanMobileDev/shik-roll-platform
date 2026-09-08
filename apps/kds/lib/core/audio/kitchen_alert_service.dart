import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// New-order audio alert for the kitchen board (ADR-1618).
///
/// Implementations coalesce bursts (several orders arriving within a short
/// window produce a single chime) and respect the station mute toggle. The
/// visual fresh-highlight never depends on playback succeeding — a failed
/// play (web autoplay policy) only flips [needsUnlockListenable].
abstract interface class KitchenAlertService {
  /// Station mute toggle (visible in the board header).
  ValueListenable<bool> get mutedListenable;
  bool get muted;
  void setMuted(bool value);

  /// Web autoplay policy: true until a user gesture unlocks the audio
  /// pipeline. Always false on native platforms.
  ValueListenable<bool> get needsUnlockListenable;

  /// Primes the audio pipeline from a user gesture («Включить звук»).
  Future<void> unlock();

  /// Plays the new-order chime, coalescing bursts within the window.
  void notifyNewOrders(int count);

  Future<void> dispose();
}

/// Asset-backed alert service (audioplayers).
final class AudioKitchenAlertService implements KitchenAlertService {
  AudioKitchenAlertService({
    AudioPlayer? player,
    this.coalesceWindow = const Duration(milliseconds: 500),
    this.assetPath = 'audio/new_order.m4a',
  }) : _player = player ?? AudioPlayer();

  static const double _fullVolume = 1;

  final AudioPlayer _player;

  /// Bursts shorter than this produce a single chime.
  final Duration coalesceWindow;

  /// Bundled alert asset (relative to `assets/`).
  final String assetPath;

  final ValueNotifier<bool> _muted = ValueNotifier(false);
  final ValueNotifier<bool> _needsUnlock = ValueNotifier(kIsWeb);
  Timer? _coalesceTimer;

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
    if (_coalesceTimer?.isActive ?? false) return;
    _coalesceTimer = Timer(coalesceWindow, _play);
  }

  Future<void> _play() async {
    if (_muted.value) return;
    try {
      await _player.stop();
      await _player.setVolume(_fullVolume);
      await _player.play(AssetSource(assetPath));
      _needsUnlock.value = false;
    } on Object {
      // Playback failure (autoplay policy, missing device output): the
      // fresh-highlight on cards is the required visual fallback; on the web
      // we additionally surface the «Включить звук» button.
      _needsUnlock.value = kIsWeb;
    }
  }

  @override
  Future<void> unlock() async {
    try {
      // A silent prime inside the user gesture satisfies the autoplay policy.
      await _player.setVolume(0);
      await _player.play(AssetSource(assetPath));
      await _player.stop();
      await _player.setVolume(_fullVolume);
      _needsUnlock.value = false;
    } on Object {
      _needsUnlock.value = kIsWeb;
    }
  }

  @override
  Future<void> dispose() async {
    _coalesceTimer?.cancel();
    await _player.dispose();
    _muted.dispose();
    _needsUnlock.dispose();
  }
}
