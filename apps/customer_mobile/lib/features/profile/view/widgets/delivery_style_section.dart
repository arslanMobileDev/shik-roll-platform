import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../bloc/user_settings_cubit.dart';
import '../../domain/delivery_vehicle.dart';

/// Секция профиля «Мой курьер»: показывает выбранный стиль доставки и
/// открывает BottomSheet выбора транспорта (ADR-1616).
class DeliveryStyleSection extends StatelessWidget {
  const DeliveryStyleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<UserSettingsCubit, UserSettingsState>(
      listenWhen: (previous, current) =>
          current.errorCode != null && previous.errorCode != current.errorCode,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Не удалось сохранить настройку. Попробуйте ещё раз.',
              ),
            ),
          );
      },
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s12,
                AppSpacing.s16,
                AppSpacing.s4,
              ),
              child: Text('Мой курьер', style: theme.textTheme.titleSmall),
            ),
            BlocBuilder<UserSettingsCubit, UserSettingsState>(
              builder: (context, state) {
                final vehicle = state.selectedCourierVehicle;
                return ListTile(
                  key: const ValueKey('delivery-style-tile'),
                  leading: VehicleIcon(vehicle: vehicle, size: 36),
                  title: const Text('Стиль доставки'),
                  subtitle: Text(vehicle.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showVehiclePicker(context),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVehiclePicker(BuildContext context) {
    final cubit = context.read<UserSettingsCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: BlocBuilder<UserSettingsCubit, UserSettingsState>(
          bloc: cubit,
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: Text(
                    'Выберите транспорт курьера',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final vehicle in DeliveryVehicle.values)
                  ListTile(
                    key: ValueKey('vehicle-option-${vehicle.name}'),
                    leading: VehicleIcon(vehicle: vehicle, size: 36),
                    title: Text(vehicle.label),
                    trailing: vehicle == state.selectedCourierVehicle
                        ? const Icon(Icons.check, color: AppColors.brandAccent)
                        : null,
                    onTap: () {
                      cubit.selectCourierVehicle(vehicle);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: AppSpacing.s8),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Иконка транспорта с эмодзи-фолбэком, если ассет не загрузился.
class VehicleIcon extends StatelessWidget {
  const VehicleIcon({super.key, required this.vehicle, required this.size});

  final DeliveryVehicle vehicle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      vehicle.imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: 256,
      cacheHeight: 256,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          Text(vehicle.fallbackEmoji, style: TextStyle(fontSize: size * 0.7)),
    );
  }
}
