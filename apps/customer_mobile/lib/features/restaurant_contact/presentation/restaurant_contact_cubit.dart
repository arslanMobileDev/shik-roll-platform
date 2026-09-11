import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/restaurant_contacts.dart';

sealed class RestaurantContactState extends Equatable {
  const RestaurantContactState();
  @override
  List<Object?> get props => [];
}

final class ContactInitial extends RestaurantContactState {
  const ContactInitial();
}

final class ContactLoading extends RestaurantContactState {
  const ContactLoading();
}

final class ContactLoaded extends RestaurantContactState {
  const ContactLoaded(this.result);
  final ContactResult result;
  @override
  List<Object?> get props => [result];
}

final class ContactError extends RestaurantContactState {
  const ContactError();
}

final class RestaurantContactCubit extends Cubit<RestaurantContactState> {
  RestaurantContactCubit(this.getContacts) : super(const ContactInitial());
  final GetRestaurantContactsUseCase getContacts;
  int _request = 0;
  Future<void> load(ContactTarget target) async {
    if (isClosed) return;
    final request = ++_request;
    emit(const ContactLoading());
    try {
      final result = await getContacts(target);
      if (!isClosed && request == _request) emit(ContactLoaded(result));
    } on Exception {
      if (!isClosed && request == _request) emit(const ContactError());
    }
  }
}
