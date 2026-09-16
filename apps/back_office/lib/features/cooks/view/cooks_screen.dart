import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/cooks_cubit.dart';
import '../data/cooks_repository.dart';

class CooksScreen extends StatelessWidget {
  const CooksScreen({super.key});
  Future<void> edit(BuildContext context, CookRecord? cook) async {
    final cubit = context.read<CooksCubit>();
    final name = TextEditingController(text: cook?.name),
        phone = TextEditingController(text: cook?.phone),
        pin = TextEditingController();
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          title: Text(cook == null ? 'Новый повар' : 'Изменить повара'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Имя'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Введите имя' : null,
                    maxLength: 100,
                  ),
                  TextFormField(
                    controller: phone,
                    enabled: cook == null,
                    decoration: const InputDecoration(labelText: 'Телефон'),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        cook != null ||
                            RegExp(r'^[78]\d{10}$').hasMatch(
                              (v ?? '').replaceAll(RegExp(r'[\s()+-]'), ''),
                            )
                        ? null
                        : 'Введите российский номер',
                  ),
                  TextFormField(
                    controller: pin,
                    obscureText: true,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: cook == null
                          ? 'PIN'
                          : 'Новый PIN (необязательно)',
                    ),
                    validator: (v) =>
                        cook != null && (v ?? '').isEmpty ||
                            RegExp(r'^\d{4,8}$').hasMatch(v ?? '')
                        ? null
                        : 'PIN: 4–8 цифр',
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => saving = true);
                      final ok = await cubit.save(
                        id: cook?.id,
                        name: name.text.trim(),
                        phone: phone.text,
                        pin: pin.text,
                      );
                      if (!dialog.mounted) return;
                      if (ok) {
                        Navigator.pop(dialog);
                      } else {
                        setState(() {
                          saving = false;
                          error = cubit.state.error;
                        });
                      }
                    },
              child: Text(saving ? 'Сохраняем…' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    pin.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<CooksCubit>();
    final s = cubit.state;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Повара', style: Theme.of(context).textTheme.headlineSmall),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: s.loading ? null : () => edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Новый повар'),
          ),
        ),
        if (s.loading) const LinearProgressIndicator(),
        if (s.error != null)
          ListTile(
            title: Text(s.error!),
            trailing: TextButton(
              onPressed: () => cubit.load(cubit.branch),
              child: const Text('Повторить'),
            ),
          ),
        if (!s.loading && s.rows.isEmpty) const Text('Повара ещё не добавлены'),
        for (final c in s.rows)
          Card(
            child: ListTile(
              title: Text(c.name),
              subtitle: Text(
                '${c.phone} · ${c.isActive ? 'Активен' : 'Заблокирован'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Изменить',
                    icon: const Icon(Icons.edit),
                    onPressed: s.loading ? null : () => edit(context, c),
                  ),
                  IconButton(
                    tooltip: c.isActive ? 'Заблокировать' : 'Разблокировать',
                    icon: Icon(c.isActive ? Icons.block : Icons.lock_open),
                    onPressed: s.loading
                        ? null
                        : () => cubit.save(
                            id: c.id,
                            name: c.name,
                            isActive: !c.isActive,
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
