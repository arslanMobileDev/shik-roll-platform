import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/user_settings_repository.dart';
import '../domain/delivery_vehicle.dart';

/// Состояние локальных настроек гостя (ADR-1616). До завершения
/// [UserSettingsCubit.load] действует безопасный дефолт
/// [DeliveryVehicle.yellowScooter], не блокируя первый кадр.
final class UserSettingsState extends Equatable {
  const UserSettingsState({
    this.selectedCourierVehicle = DeliveryVehicle.yellowScooter,
    this.isLoaded = false,
    this.errorCode,
  });

  final DeliveryVehicle selectedCourierVehicle;

  /// `true`, когда первичное чтение из storage завершено.
  final bool isLoaded;

  /// Код последней ошибки записи (`SETTINGS_WRITE_FAILED`); `null` — ошибок нет.
  final String? errorCode;

  UserSettingsState copyWith({
    DeliveryVehicle? selectedCourierVehicle,
    bool? isLoaded,
    String? errorCode,
    bool clearError = false,
  }) {
    return UserSettingsState(
      selectedCourierVehicle:
          selectedCourierVehicle ?? this.selectedCourierVehicle,
      isLoaded: isLoaded ?? this.isLoaded,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }

  @override
  List<Object?> get props => [selectedCourierVehicle, isLoaded, errorCode];
}

/// Единый источник настроек для профиля и трекера заказа. Создаётся один раз
/// над корневым navigator и вызывает [load] при старте приложения.
class UserSettingsCubit extends Cubit<UserSettingsState> {
  UserSettingsCubit(this._repository) : super(const UserSettingsState());

  static const writeFailedErrorCode = 'SETTINGS_WRITE_FAILED';

  final UserSettingsRepository _repository;

  Future<void> load() async {
    try {
      final vehicle = await _repository.readCourierVehicle();
      emit(
        state.copyWith(
          selectedCourierVehicle: vehicle,
          isLoaded: true,
          clearError: true,
        ),
      );
    } catch (_) {
      // Чтение не критично: остаёмся на дефолте, не блокируя UI.
      emit(state.copyWith(isLoaded: true, clearError: true));
    }
  }

  /// Оптимистично обновляет состояние, затем сохраняет значение. При ошибке
  /// записи состояние откатывается и выставляется [writeFailedErrorCode].
  Future<void> selectCourierVehicle(DeliveryVehicle vehicle) async {
    final previous = state.selectedCourierVehicle;
    if (previous == vehicle && state.errorCode == null) return;
    emit(state.copyWith(selectedCourierVehicle: vehicle, clearError: true));
    try {
      await _repository.writeCourierVehicle(vehicle);
    } catch (_) {
      emit(
        state.copyWith(
          selectedCourierVehicle: previous,
          errorCode: writeFailedErrorCode,
        ),
      );
    }
  }
}
