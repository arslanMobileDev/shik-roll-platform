import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Service modes of a branch (UI-805 branch configuration).
final class BranchServiceModes extends Equatable {
  const BranchServiceModes({
    this.courierDelivery = true,
    this.counterPickup = true,
    this.dineIn = true,
  });

  final bool courierDelivery;
  final bool counterPickup;
  final bool dineIn;

  BranchServiceModes copyWith({
    bool? courierDelivery,
    bool? counterPickup,
    bool? dineIn,
  }) {
    return BranchServiceModes(
      courierDelivery: courierDelivery ?? this.courierDelivery,
      counterPickup: counterPickup ?? this.counterPickup,
      dineIn: dineIn ?? this.dineIn,
    );
  }

  @override
  List<Object?> get props => [courierDelivery, counterPickup, dineIn];
}

/// Holds per-branch service mode toggles.
///
/// UI-805 scope: kept client-side; a branch-settings endpoint will be
/// wired once the API contract is extended.
final class BranchSettingsCubit extends Cubit<BranchServiceModes> {
  BranchSettingsCubit() : super(const BranchServiceModes());

  final Map<String, BranchServiceModes> _byBranch = {};
  String _branchId = '';

  void selectBranch(String branchId) {
    _branchId = branchId;
    emit(_byBranch[branchId] ?? const BranchServiceModes());
  }

  void toggleCourierDelivery(bool value) => _update(
    (modes) => modes.copyWith(courierDelivery: value),
  );

  void toggleCounterPickup(bool value) =>
      _update((modes) => modes.copyWith(counterPickup: value));

  void toggleDineIn(bool value) =>
      _update((modes) => modes.copyWith(dineIn: value));

  void _update(BranchServiceModes Function(BranchServiceModes) change) {
    final next = change(state);
    _byBranch[_branchId] = next;
    emit(next);
  }
}
