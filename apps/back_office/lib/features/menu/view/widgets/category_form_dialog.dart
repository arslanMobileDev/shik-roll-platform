import 'package:flutter/material.dart';

import '../../data/models/menu_category_ref.dart';

/// Modal create/edit form for a menu category.
///
/// Holds no API access of its own: it hands the draft to [onSubmit] and stays
/// open when that throws, so the message lands next to the fields instead of in
/// a snackbar behind the dialog. Pops with the saved category on success,
/// `null` on cancel.
class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({super.key, required this.onSubmit, this.initial});

  /// When non-null the dialog edits this category instead of creating one.
  final MenuCategoryRef? initial;

  /// Performs the POST/PATCH through the bloc.
  final Future<MenuCategoryRef> Function(CategoryDraft draft) onSubmit;

  static Future<MenuCategoryRef?> show(
    BuildContext context, {
    required Future<MenuCategoryRef> Function(CategoryDraft draft) onSubmit,
    MenuCategoryRef? initial,
  }) {
    return showDialog<MenuCategoryRef>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryFormDialog(onSubmit: onSubmit, initial: initial),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isActive;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final description = _descriptionController.text.trim();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSubmit(
        CategoryDraft(
          name: _nameController.text.trim(),
          description: description.isEmpty ? null : description,
          isActive: _isActive,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'Редактировать категорию' : 'Новая категория',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('categoryForm.name'),
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Название'),
                  textInputAction: TextInputAction.next,
                  maxLength: 120,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Укажите название'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('categoryForm.description'),
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    hintText: 'Необязательно',
                  ),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                ),
                if (_isEditing)
                  SwitchListTile(
                    key: const ValueKey('categoryForm.active'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Показывать в меню'),
                    subtitle: const Text(
                      'Скрытая категория остаётся здесь и уходит из меню гостя',
                    ),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    key: const ValueKey('categoryForm.error'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const ValueKey('categoryForm.save'),
                      onPressed: _isSaving ? null : _submit,
                      child: Text(_isEditing ? 'Сохранить' : 'Создать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
