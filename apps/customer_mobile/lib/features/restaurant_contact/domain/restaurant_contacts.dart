import 'package:equatable/equatable.dart';

final class ContactTarget extends Equatable {
  const ContactTarget.branch(this.branchId) : orderId = null;
  const ContactTarget.order(this.orderId) : branchId = null;
  final String? branchId;
  final String? orderId;
  String get cacheKey =>
      orderId != null ? 'order:$orderId' : 'branch:$branchId';
  bool get isValid => (orderId ?? branchId ?? '').trim().isNotEmpty;
  @override
  List<Object?> get props => [branchId, orderId];
}

final class RestaurantContacts extends Equatable {
  const RestaurantContacts({
    required this.branchId,
    this.phone,
    this.whatsapp,
    this.telegram,
    this.workingHours,
    this.address,
  });
  final String branchId;
  final String? phone;
  final String? whatsapp;
  final String? telegram;
  final String? workingHours;
  final String? address;
  bool get isEmpty => [
    phone,
    whatsapp,
    telegram,
    workingHours,
    address,
  ].every((value) => value == null);
  @override
  List<Object?> get props => [
    branchId,
    phone,
    whatsapp,
    telegram,
    workingHours,
    address,
  ];
}

enum ContactSource { server, cache, defaults }

final class ContactResult extends Equatable {
  const ContactResult(this.contacts, this.source);
  final RestaurantContacts contacts;
  final ContactSource source;
  @override
  List<Object?> get props => [contacts, source];
}

final class ContactsUnavailable implements Exception {
  const ContactsUnavailable();
}

abstract interface class RestaurantContactsRepository {
  Future<ContactResult> getContacts(ContactTarget target);
}

final class GetRestaurantContactsUseCase {
  const GetRestaurantContactsUseCase(this.repository);
  final RestaurantContactsRepository repository;
  Future<ContactResult> call(ContactTarget target) {
    if (!target.isValid) return Future.error(const ContactsUnavailable());
    return repository.getContacts(target);
  }
}
