import 'package:back_office/features/branch_settings/bloc/branch_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BranchSettingsCubit', () {
    test('starts with all service modes enabled', () {
      final cubit = BranchSettingsCubit();
      addTearDown(cubit.close);
      expect(cubit.state.courierDelivery, isTrue);
      expect(cubit.state.counterPickup, isTrue);
      expect(cubit.state.dineIn, isTrue);
    });

    test('toggles courier delivery only', () {
      final cubit = BranchSettingsCubit();
      addTearDown(cubit.close);
      cubit.toggleCourierDelivery(false);
      expect(cubit.state.courierDelivery, isFalse);
      expect(cubit.state.counterPickup, isTrue);
      expect(cubit.state.dineIn, isTrue);
    });

    test('keeps settings per branch', () {
      final cubit = BranchSettingsCubit();
      addTearDown(cubit.close);
      cubit.selectBranch('branch-a');
      cubit.toggleDineIn(false);

      cubit.selectBranch('branch-b');
      expect(cubit.state.dineIn, isTrue);

      cubit.selectBranch('branch-a');
      expect(cubit.state.dineIn, isFalse);
    });
  });
}
