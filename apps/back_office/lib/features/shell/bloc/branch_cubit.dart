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
final class BranchCubit extends Cubit<Branch> {
  BranchCubit() : super(branches.first);

  static const List<Branch> branches = [
    Branch(
      id: '904331fe-5efe-4ca8-9c17-ceccc6dd3839',
      name: 'SHIK ROLL · Центр',
    ),
  ];

  void select(Branch branch) => emit(branch);
}
