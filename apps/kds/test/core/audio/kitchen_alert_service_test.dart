import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/audio/kitchen_alert_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockAudioPlayer player;

  setUpAll(() {
    registerFallbackValue(AssetSource('audio/new_order.m4a'));
  });

  setUp(() {
    player = MockAudioPlayer();
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.setVolume(any())).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
  });

  AudioKitchenAlertService buildService({
    Duration coalesceWindow = const Duration(milliseconds: 40),
  }) => AudioKitchenAlertService(
    player: player,
    coalesceWindow: coalesceWindow,
  );

  test('notifyNewOrders plays the bundled chime once after the window', () async {
    final service = buildService();
    addTearDown(service.dispose);

    service.notifyNewOrders(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    verify(() => player.play(any(that: isA<AssetSource>()))).called(1);
  });

  test('a burst of arrivals inside the window coalesces to a single chime', () async {
    final service = buildService();
    addTearDown(service.dispose);

    service
      ..notifyNewOrders(1)
      ..notifyNewOrders(2)
      ..notifyNewOrders(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    verify(() => player.play(any())).called(1);
  });

  test('muted station stays silent', () async {
    final service = buildService();
    addTearDown(service.dispose);

    service.setMuted(true);
    service.notifyNewOrders(3);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    verifyNever(() => player.play(any()));
    expect(service.mutedListenable.value, isTrue);
  });

  test('a playback failure is swallowed (visual highlight stays the fallback)', () async {
    when(() => player.play(any())).thenThrow(Exception('autoplay blocked'));
    final service = buildService();
    addTearDown(service.dispose);

    service.notifyNewOrders(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    verify(() => player.play(any())).called(1);
  });

  test('unlock primes the pipeline silently and restores full volume', () async {
    final service = buildService();
    addTearDown(service.dispose);

    await service.unlock();

    verifyInOrder([
      () => player.setVolume(0),
      () => player.play(any()),
      () => player.stop(),
      () => player.setVolume(1),
    ]);
    expect(service.needsUnlockListenable.value, isFalse);
  });
}
