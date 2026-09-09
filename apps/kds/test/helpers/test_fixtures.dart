import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kds/core/audio/kitchen_alert_service.dart';
import 'package:kds/core/storage/kitchen_token_storage.dart';
import 'package:kds/features/auth/data/kitchen_auth_repository.dart';
import 'package:kds/features/kds/data/kds_order_models.dart';
import 'package:kds/features/kds/data/kds_orders_repository.dart';
import 'package:kds/features/kds/data/kitchen_events_client.dart';
import 'package:kds/features/shift/data/cook_shift_models.dart';
import 'package:kds/features/shift/data/cook_shift_repository.dart';

/// Fixed reference clock for deterministic timer assertions.
final DateTime kNow = DateTime(2026, 8, 31, 12, 0);

KdsOrderItemModifier buildModifier({
  String id = 'mod-1',
  String name = 'Соус унаги',
  int quantity = 1,
}) => KdsOrderItemModifier(id: id, name: name, quantity: quantity);

KdsOrderItem buildItem({
  String id = 'item-1',
  String name = 'Филадельфия классик',
  int quantity = 1,
  String? comment,
  List<KdsOrderItemModifier> modifiers = const [],
}) => KdsOrderItem(
  id: id,
  name: name,
  quantity: quantity,
  comment: comment,
  modifiers: modifiers,
);

KdsOrder buildOrder({
  String id = 'order-1',
  String orderNumber = '1001',
  int version = 1,
  KdsOrderStatus status = KdsOrderStatus.confirmed,
  KdsOrderType type = KdsOrderType.dineIn,
  DateTime? confirmedAt,
  DateTime? cookingStartedAt,
  DateTime? readyAt,
  String? tableNumber,
  String? comment,
  List<KdsOrderItem> items = const [],
}) => KdsOrder(
  id: id,
  orderNumber: orderNumber,
  version: version,
  status: status,
  type: type,
  confirmedAt: confirmedAt ?? kNow.subtract(const Duration(minutes: 5)),
  cookingStartedAt: cookingStartedAt,
  readyAt: readyAt,
  tableNumber: tableNumber,
  comment: comment,
  items: items,
);

KitchenSession buildSession({
  String token = 'test-token',
  String terminalId = 'terminal-1',
  String terminalCode = 'KDS-01',
  String branchId = 'branch-central',
  DateTime? storedAt,
}) => KitchenSession(
  token: token,
  expiresInSeconds: 12 * 60 * 60,
  terminalId: terminalId,
  terminalCode: terminalCode,
  terminalName: 'Тестовый терминал',
  branchId: branchId,
  // Expiry is checked against the real clock — anchor to it, not kNow.
  storedAt: storedAt ?? DateTime.now(),
);

/// Mutable in-memory repository for widget/bloc tests.
final class TestKdsOrdersRepository implements KdsOrdersRepository {
  TestKdsOrdersRepository({List<KdsOrder> orders = const []}) {
    this.orders = List.of(orders);
  }

  List<KdsOrder> orders = [];
  final List<(String orderId, KdsOrderStatus status, int expectedVersion)>
  statusCalls = [];

  /// Cook/shift attribution captured from update calls.
  final List<(String orderId, String? cookId, String? shiftId)>
  attributionCalls = [];
  Object? fetchError;
  Object? updateError;
  DateTime serverTime = kNow;
  int fetchCount = 0;

  /// When set, the next update awaits it — deterministic in-flight states.
  Completer<KdsOrder>? updateCompleter;

  @override
  Future<KitchenBoardSnapshot> fetchSnapshot() async {
    fetchCount++;
    if (fetchError != null) throw fetchError!;
    return KitchenBoardSnapshot(
      serverTime: serverTime,
      orders: List.unmodifiable(orders),
    );
  }

  @override
  Future<KdsOrder> updateOrderStatus({
    required String orderId,
    required KdsOrderStatus status,
    required int expectedVersion,
    String? cookId,
    String? shiftId,
  }) {
    statusCalls.add((orderId, status, expectedVersion));
    attributionCalls.add((orderId, cookId, shiftId));
    if (updateError != null) return Future.error(updateError!);
    final completer = updateCompleter;
    if (completer != null) {
      updateCompleter = null;
      return completer.future;
    }
    return Future.value(_applyUpdate(orderId, status));
  }

  /// Resolves a pending update (see [updateCompleter]) the way the server
  /// would: version bump and fresh server timestamps.
  KdsOrder applyServerUpdate(String orderId, KdsOrderStatus status) =>
      _applyUpdate(orderId, status);

  KdsOrder _applyUpdate(String orderId, KdsOrderStatus status) {
    final index = orders.indexWhere((o) => o.id == orderId);
    final now = DateTime.now();
    final updated = orders[index].copyWith(
      status: status,
      version: orders[index].version + 1,
      cookingStartedAt: status == KdsOrderStatus.cooking ? () => now : null,
      readyAt: status == KdsOrderStatus.ready ? () => now : null,
    );
    orders = [...orders]..[index] = updated;
    return updated;
  }
}

/// Manually driven kitchen SSE client for bloc/view tests.
///
/// Every [connect] call records a new subscription; tests push signals,
/// complete or fail the current stream through [emitSignal], [dropStream]
/// and [failStream].
final class TestKitchenEventsClient implements KitchenEventsClient {
  final List<StreamController<KitchenStreamSignal>> connections = [];
  int connectCount = 0;

  @override
  Stream<KitchenStreamSignal> connect() {
    connectCount++;
    final controller = StreamController<KitchenStreamSignal>();
    connections.add(controller);
    return controller.stream;
  }

  StreamController<KitchenStreamSignal> get current => connections.last;

  void emitSignal(KitchenStreamSignal signal) {
    if (!current.isClosed) current.add(signal);
  }

  /// Server closed the stream gracefully.
  void dropStream() {
    if (!current.isClosed) current.close();
  }

  /// Stream failed with a transport error.
  void failStream(Object error) {
    if (!current.isClosed) {
      current.addError(error);
    }
  }
}

/// Recording alert service: no real audio in tests.
final class TestKitchenAlertService implements KitchenAlertService {
  final List<int> notifyCounts = [];
  final ValueNotifier<bool> mutedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> needsUnlockNotifier = ValueNotifier(false);
  int unlockCalls = 0;

  @override
  ValueListenable<bool> get mutedListenable => mutedNotifier;

  @override
  bool get muted => mutedNotifier.value;

  @override
  void setMuted(bool value) => mutedNotifier.value = value;

  @override
  ValueListenable<bool> get needsUnlockListenable => needsUnlockNotifier;

  @override
  Future<void> unlock() async {
    unlockCalls++;
    needsUnlockNotifier.value = false;
  }

  @override
  void notifyNewOrders(int count) => notifyCounts.add(count);

  @override
  Future<void> dispose() async {}
}

/// In-memory token storage for auth tests.
final class TestKitchenTokenStorage implements KitchenTokenStorage {
  KitchenSession? stored;
  int clearCount = 0;

  @override
  Future<KitchenSession?> read() async => stored;

  @override
  Future<void> write(KitchenSession session) async {
    stored = session;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    stored = null;
  }
}

/// Scriptable auth repository for cubit/login tests.
final class TestKitchenAuthRepository implements KitchenAuthRepository {
  final List<(String terminalCode, String pin)> loginCalls = [];
  Object? loginError;
  KitchenSession? session;

  @override
  Future<KitchenSession> login({
    required String terminalCode,
    required String pin,
  }) async {
    loginCalls.add((terminalCode, pin));
    if (loginError != null) throw loginError!;
    return session ?? buildSession(token: 'token-for-$terminalCode');
  }
}

ActiveCook buildCook({
  String id = 'cook-1',
  String name = 'Ахмед',
  CookRole role = CookRole.sushiChef,
  int completedOrders = 0,
  int? avgPrepSeconds,
}) => ActiveCook(
  id: id,
  name: name,
  role: role,
  clockInAt: kNow.subtract(const Duration(hours: 2)),
  completedOrders: completedOrders,
  avgPrepSeconds: avgPrepSeconds,
);

/// Mutable in-memory shift repository for widget/bloc tests.
final class TestCookShiftRepository implements CookShiftRepository {
  TestCookShiftRepository({
    List<ActiveCook> cooks = const [],
    this.shiftId = 'shift-1',
  }) : cooks = List.of(cooks);

  final String shiftId;
  List<ActiveCook> cooks;
  Object? fetchError;
  Object? clockInError;
  Object? clockOutError;
  final List<(String pin, String name, CookRole role)> clockInCalls = [];
  final List<(String cookId, String shiftId)> clockOutCalls = [];

  @override
  Future<ActiveShift> fetchActiveShift({required String branchId}) async {
    if (fetchError != null) throw fetchError!;
    return ActiveShift(
      shiftId: shiftId,
      branchId: branchId,
      cooks: List.unmodifiable(cooks),
    );
  }

  @override
  Future<ClockInResult> clockIn({
    required String branchId,
    required String pin,
    required String name,
    required CookRole role,
  }) async {
    if (clockInError != null) throw clockInError!;
    clockInCalls.add((pin, name, role));
    final cook = ActiveCook(
      id: 'cook-$pin',
      name: name,
      role: role,
      clockInAt: kNow,
    );
    cooks.add(cook);
    return (shiftId: shiftId, cook: cook);
  }

  @override
  Future<void> clockOut({
    required String cookId,
    required String shiftId,
  }) async {
    if (clockOutError != null) throw clockOutError!;
    clockOutCalls.add((cookId, shiftId));
    cooks.removeWhere((c) => c.id == cookId);
  }
}
