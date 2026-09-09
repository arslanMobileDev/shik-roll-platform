import 'package:flutter_test/flutter_test.dart';
import 'package:kds/core/audio/kitchen_alert_service.dart';

void main() {
  late int playCount;

  setUp(() => playCount = 0);

  SystemKitchenAlertService buildService({
    Duration coalesceWindow = const Duration(milliseconds: 40),
  }) => SystemKitchenAlertService(
    player: () async => playCount++,
    coalesceWindow: coalesceWindow,
  );

  test('notifyNewOrders plays one system alert after the window', () async {
    final service = buildService();
    addTearDown(service.dispose);
    service.notifyNewOrders(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(playCount, 1);
  });

  test('a burst of arrivals is coalesced to one system alert', () async {
    final service = buildService();
    addTearDown(service.dispose);
    service
      ..notifyNewOrders(1)
      ..notifyNewOrders(2)
      ..notifyNewOrders(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(playCount, 1);
  });

  test('muted station stays silent', () async {
    final service = buildService();
    addTearDown(service.dispose);
    service.setMuted(true);
    service.notifyNewOrders(3);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(playCount, 0);
    expect(service.mutedListenable.value, isTrue);
  });

  test('a playback failure is swallowed', () async {
    final service = SystemKitchenAlertService(
      player: () => throw Exception('system alert unavailable'),
      coalesceWindow: const Duration(milliseconds: 20),
    );
    addTearDown(service.dispose);
    service.notifyNewOrders(1);
    await Future<void>.delayed(const Duration(milliseconds: 60));
  });
}
