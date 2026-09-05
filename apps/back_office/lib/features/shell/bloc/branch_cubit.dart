import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A restaurant branch (point of service).
final class Branch extends Equatable {
  const Branch({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Active branch selection for the top bar [BranchSelector].
///
/// Demo directory of branches; a branches endpoint will replace the
/// static list once exposed by the API contract.
final class BranchCubit extends Cubit<Branch> {
  BranchCubit() : super(branches.first);

  static const List<Branch> branches = [
    Branch(id: 'branch-center', name: 'SHIK ROLL · Центр'),
    Branch(id: 'branch-north', name: 'SHIK ROLL · Север'),
  ];

  void select(Branch branch) => emit(branch);
}
