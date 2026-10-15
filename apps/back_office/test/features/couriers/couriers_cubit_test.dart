import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:back_office/features/couriers/bloc/couriers_cubit.dart';
import 'package:back_office/features/couriers/data/couriers_repository.dart';

class DelayedRepository implements CouriersRepository {
  final loads = <String, Completer<List<CourierRecord>>>{};
  int saves = 0;
  bool failRefresh = false;

  /// Which half of the list each call asked for, in order.
  final asked = <bool>[];
  final restored = <String>[];
  String? restoreFailure;
  @override
  Future<List<CourierRecord>> list(
    String branchId, {
    bool includeDeleted = false,
  }) {
    asked.add(includeDeleted);
    if (failRefresh) throw const CouriersApiException('refresh failed');
    return (loads[branchId] = Completer<List<CourierRecord>>()).future;
  }

  @override
  Future<void> restore(String id) async {
    restored.add(id);
    if (restoreFailure != null) {
      throw CouriersApiException(restoreFailure!);
    }
  }

  @override
  Future<void> save({
    String? id,
    required String branchId,
    required String name,
    String? phone,
    String? pin,
    bool? isActive,
  }) async {
    saves++;
    failRefresh = true;
  }
}

void main() {
  test('late response cannot overwrite the selected branch', () async {
    final repo = DelayedRepository();
    final cubit = CouriersCubit(repo);
    addTearDown(cubit.close);
    final first = cubit.load('first');
    final second = cubit.load('second');
    repo.loads['second']!.complete([]);
    await second;
    repo.loads['first']!.complete([]);
    await first;
    expect(cubit.state.branchId, 'second');
    expect(cubit.state.status, CouriersStatus.loaded);
  });
  test(
    'successful mutation remains successful if list refresh fails',
    () async {
      final repo = DelayedRepository();
      final cubit = CouriersCubit(repo);
      addTearDown(cubit.close);
      final load = cubit.load('branch');
      repo.loads['branch']!.complete([]);
      await load;
      expect(
        await cubit.save(name: 'Иван', phone: '9280000000', pin: '1234'),
        isTrue,
      );
      expect(repo.saves, 1);
      expect(cubit.state.status, CouriersStatus.error);
    },
  );
  test('loadDeleted asks the backend for the deleted half', () async {
    final repo = DelayedRepository();
    final cubit = CouriersCubit(repo);
    addTearDown(cubit.close);
    final active = cubit.load('branch');
    repo.loads['branch']!.complete([]);
    await active;
    expect(cubit.state.includeDeleted, isFalse);

    final deleted = cubit.loadDeleted();
    repo.loads['branch']!.complete([]);
    await deleted;
    expect(repo.asked, [false, true]);
    expect(cubit.state.includeDeleted, isTrue);
  });
  test('restore reloads the deleted tab it was called from', () async {
    final repo = DelayedRepository();
    final cubit = CouriersCubit(repo);
    addTearDown(cubit.close);
    // The tab chips only exist once a branch is loaded, so the real order is
    // active first, deleted second.
    final active = cubit.load('branch');
    repo.loads['branch']!.complete([]);
    await active;
    final deleted = cubit.loadDeleted();
    repo.loads['branch']!.complete([]);
    await deleted;

    final restored = cubit.restore('courier');
    await Future<void>.delayed(Duration.zero);
    repo.loads['branch']!.complete([]);

    expect(await restored, isTrue);
    expect(repo.restored, ['courier']);
    expect(repo.asked, [false, true, true]);
    expect(cubit.state.includeDeleted, isTrue);
    expect(cubit.state.status, CouriersStatus.loaded);
  });
  test('a refused restore keeps the row and surfaces the reason', () async {
    final repo = DelayedRepository();
    final cubit = CouriersCubit(repo);
    addTearDown(cubit.close);
    final active = cubit.load('branch');
    repo.loads['branch']!.complete([]);
    await active;
    final deleted = cubit.loadDeleted();
    repo.loads['branch']!.complete([]);
    await deleted;
    repo.restoreFailure = 'Этот телефон уже занят другим курьером.';

    expect(await cubit.restore('courier'), isFalse);
    expect(cubit.state.error, 'Этот телефон уже занят другим курьером.');
    expect(cubit.state.saving, isFalse);
    // No refresh: the list would answer the same row, and the message would go.
    expect(repo.asked, [false, true]);
  });
  test('normalizes all supported Russian phone forms', () {
    for (final value in [
      '9280000000',
      '89280000000',
      '+79280000000',
      '+7 (928) 000-00-00',
    ]) {
      expect(normalizeCourierPhone(value), '+79280000000');
    }
    expect(isRussianCourierPhone('+12345'), isFalse);
  });
}
