import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:back_office/features/couriers/bloc/couriers_cubit.dart';
import 'package:back_office/features/couriers/data/couriers_repository.dart';

class DelayedRepository implements CouriersRepository {
  final loads = <String, Completer<List<CourierRecord>>>{};
  int saves = 0;
  bool failRefresh = false;
  @override
  Future<List<CourierRecord>> list(String branchId) {
    if (failRefresh) throw const CouriersApiException('refresh failed');
    return (loads[branchId] = Completer<List<CourierRecord>>()).future;
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
