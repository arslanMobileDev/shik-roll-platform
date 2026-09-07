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
      id: '47ad77ce-acf4-4778-a185-974d3a4a2413',
      name: 'SHIK ROLL · Центр',
    ),
  ];

  void select(Branch branch) => emit(branch);
}
