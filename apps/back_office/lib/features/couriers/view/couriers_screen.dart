import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/couriers_cubit.dart';
import '../data/couriers_repository.dart';

class CouriersScreen extends StatelessWidget {
  const CouriersScreen({super.key});
  Future<void> _edit(BuildContext context, CourierRecord? courier) async {
    final cubit = context.read<CouriersCubit>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CourierDialog(
        cubit: cubit,
        courier: courier,
        branchId: cubit.state.branchId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CouriersCubit>();
    final s = cubit.state;
    final busy = s.saving || s.status == CouriersStatus.loading;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Курьеры', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('new-courier'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.terracotta,
            ),
            onPressed: busy ? null : () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Новый курьер'),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (s.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.error!),
                TextButton(
                  onPressed: busy ? null : () => cubit.load(s.branchId),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        if (s.status == CouriersStatus.loaded && s.rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Курьеры ещё не добавлены'),
          ),
        for (final courier in s.rows)
          Card(
            key: ValueKey('courier-${courier.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courier.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(courier.phone),
                  Text(
                    '${courier.isActive ? 'Активен' : 'Заблокирован'} · ${courier.isAvailable ? 'Свободен' : 'Занят'}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : () => _edit(context, courier),
                        icon: const Icon(Icons.edit),
                        label: const Text('Изменить'),
                      ),
                      TextButton.icon(
                        key: ValueKey('toggle-${courier.id}'),
                        onPressed: busy
                            ? null
                            : () => cubit.save(
                                id: courier.id,
                                name: courier.name,
                                isActive: !courier.isActive,
                              ),
                        icon: Icon(
                          courier.isActive ? Icons.block : Icons.lock_open,
                        ),
                        label: Text(
                          courier.isActive ? 'Заблокировать' : 'Разблокировать',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CourierDialog extends StatefulWidget {
  const _CourierDialog({
    required this.cubit,
    required this.courier,
    required this.branchId,
  });
  final CouriersCubit cubit;
  final CourierRecord? courier;
  final String branchId;
  @override
  State<_CourierDialog> createState() => _CourierDialogState();
}

class _CourierDialogState extends State<_CourierDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.courier?.name);
  late final _phone = TextEditingController(text: widget.courier?.phone);
  final _pin = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.cubit.save(
      id: widget.courier?.id,
      name: _name.text.trim(),
      phone: _phone.text,
      pin: _pin.text,
      expectedBranchId: widget.branchId,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.cubit.state.error ??
            'Филиал изменился или запрос ещё выполняется. Откройте форму снова.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.courier == null ? 'Новый курьер' : 'Изменить курьера'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('courier-name'),
                controller: _name,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Имя'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Введите имя' : null,
              ),
              TextFormField(
                key: const Key('courier-phone'),
                controller: _phone,
                readOnly: widget.courier != null,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
                validator: (v) => isRussianCourierPhone(v ?? '')
                    ? null
                    : 'Введите российский телефон',
              ),
              TextFormField(
                key: const Key('courier-pin'),
                controller: _pin,
                enabled: !_saving,
                obscureText: true,
                maxLength: 8,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: widget.courier == null
                      ? 'PIN'
                      : 'Новый PIN (необязательно)',
                ),
                validator: (v) {
                  if (widget.courier != null && (v ?? '').isEmpty) return null;
                  return RegExp(r'^\d{4,8}$').hasMatch(v ?? '')
                      ? null
                      : 'PIN: 4–8 цифр';
                },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('save-courier'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.terracotta),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
        ),
      ],
    ),
  );
}
