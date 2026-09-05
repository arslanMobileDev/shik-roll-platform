import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../bloc/cook_shift_cubit.dart';
import '../../data/cook_shift_models.dart';

/// Opens the cook selection dialog, keeping the station's [CookShiftCubit].
Future<void> showShiftSelectDialog(BuildContext context) {
  final cubit = context.read<CookShiftCubit>();
  return showDialog<void>(
    context: context,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const ShiftSelectDialog()),
  );
}

/// Station cook picker: quick-select among cooks already on the line or
/// clock-in by 4-digit PIN (+ name and station for a new shift).
class ShiftSelectDialog extends StatefulWidget {
  const ShiftSelectDialog({super.key});

  @override
  State<ShiftSelectDialog> createState() => _ShiftSelectDialogState();
}

class _ShiftSelectDialogState extends State<ShiftSelectDialog> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  CookRole _role = CookRole.sushiChef;
  String? _formError;

  @override
  void dispose() {
    _pinController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CookShiftCubit>().state;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Смена кухни'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.lineCooks.isNotEmpty) ...[
                Text('На линии', style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                for (final cook in state.lineCooks)
                  ListTile(
                    key: Key('select-cook-${cook.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        cook.name.characters.first.toUpperCase(),
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(cook.name),
                    subtitle: Text(
                      '${cook.role.label} · выполнено ${cook.completedOrders}',
                    ),
                    trailing: cook.id == state.currentCookId
                        ? const Icon(Icons.check, color: AppColors.success)
                        : null,
                    onTap: () {
                      context.read<CookShiftCubit>().selectCook(cook.id);
                      Navigator.of(context).pop();
                    },
                  ),
                const Divider(height: AppSpacing.s32),
              ],
              ..._pinForm(context, state),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('shift-clock-in-button'),
          onPressed: state.actionInFlight ? null : _clockIn,
          child: state.actionInFlight
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Начать смену'),
        ),
      ],
    );
  }

  List<Widget> _pinForm(BuildContext context, CookShiftState state) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Text('Вход по PIN', style: textTheme.titleSmall),
      const SizedBox(height: AppSpacing.s8),
      TextField(
        key: const Key('shift-pin-field'),
        controller: _pinController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 4,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: '4-значный PIN',
          counterText: '',
        ),
      ),
      const SizedBox(height: AppSpacing.s8),
      TextField(
        key: const Key('shift-name-field'),
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Имя'),
      ),
      const SizedBox(height: AppSpacing.s12),
      SegmentedButton<CookRole>(
        key: const Key('shift-role-segments'),
        segments: [
          for (final role in CookRole.values)
            ButtonSegment(value: role, label: Text(role.label)),
        ],
        selected: {_role},
        onSelectionChanged: (selection) =>
            setState(() => _role = selection.first),
      ),
      if (_formError != null) ...[
        const SizedBox(height: AppSpacing.s8),
        Text(
          _formError!,
          style: textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
      ],
      if (state.errorMessage != null) ...[
        const SizedBox(height: AppSpacing.s8),
        Text(
          state.errorMessage!,
          style: textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
      ],
    ];
  }

  Future<void> _clockIn() async {
    final pin = _pinController.text.trim();
    final name = _nameController.text.trim();
    if (pin.length != 4) {
      setState(() => _formError = 'Введите 4 цифры PIN');
      return;
    }
    if (name.isEmpty) {
      setState(() => _formError = 'Укажите имя повара');
      return;
    }
    setState(() => _formError = null);

    final cubit = context.read<CookShiftCubit>();
    await cubit.clockIn(pin: pin, name: name, role: _role);
    if (mounted && cubit.state.errorMessage == null) {
      Navigator.of(context).pop();
    }
  }
}
