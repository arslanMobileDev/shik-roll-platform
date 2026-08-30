import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'pos_config.dart';

/// Active brand/branch context of the cashier session.
final class PosContextState extends Equatable {
  const PosContextState({required this.brandId, required this.branchId});

  final String brandId;
  final String branchId;

  PosContextState copyWith({String? brandId, String? branchId}) {
    return PosContextState(
      brandId: brandId ?? this.brandId,
      branchId: branchId ?? this.branchId,
    );
  }

  @override
  List<Object?> get props => [brandId, branchId];
}

/// Holds the brand/branch the POS operates against; the catalog reloads
/// whenever the context changes.
class PosContextCubit extends Cubit<PosContextState> {
  PosContextCubit()
    : super(
        const PosContextState(
          brandId: PosConfig.defaultBrandId,
          branchId: PosConfig.defaultBranchId,
        ),
      );

  void selectBrand(String brandId) {
    if (brandId != state.brandId) emit(state.copyWith(brandId: brandId));
  }

  void selectBranch(String branchId) {
    if (branchId != state.branchId) emit(state.copyWith(branchId: branchId));
  }
}
