import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../bloc/checkout_cubit.dart';

/// Структурированный адрес доставки: улица и дом обязательны (см.
/// [CheckoutForm.hasDeliveryAddress]), остальные поля опциональны.
/// Показывается только при `OrderType.delivery`.
class DeliveryAddressForm extends StatelessWidget {
  const DeliveryAddressForm({super.key});

  @override
  Widget build(BuildContext context) {
    final checkout = context.read<CheckoutCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('street-field'),
          onChanged: checkout.streetChanged,
          decoration: const InputDecoration(
            labelText: 'Улица *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('house-field'),
                onChanged: checkout.houseChanged,
                decoration: const InputDecoration(
                  labelText: 'Дом *',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: TextField(
                key: const ValueKey('apartment-field'),
                onChanged: checkout.apartmentChanged,
                decoration: const InputDecoration(
                  labelText: 'Квартира',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('entrance-field'),
                onChanged: checkout.entranceChanged,
                decoration: const InputDecoration(
                  labelText: 'Подъезд',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: TextField(
                key: const ValueKey('floor-field'),
                onChanged: checkout.floorChanged,
                decoration: const InputDecoration(
                  labelText: 'Этаж',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: TextField(
                key: const ValueKey('intercom-field'),
                onChanged: checkout.intercomChanged,
                decoration: const InputDecoration(
                  labelText: 'Домофон',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
