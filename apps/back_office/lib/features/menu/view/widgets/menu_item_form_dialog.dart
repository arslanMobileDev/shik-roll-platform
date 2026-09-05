import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../data/models/menu_item.dart';

/// Modal create/edit form for a catalog position.
///
/// Pops with a [MenuItemDraft] on successful validation, `null` on cancel.
class MenuItemFormDialog extends StatefulWidget {
  const MenuItemFormDialog({super.key, this.initial});

  /// When non-null the dialog edits this item instead of creating one.
  final MenuItem? initial;

  static Future<MenuItemDraft?> show(
    BuildContext context, {
    MenuItem? initial,
  }) {
    return showDialog<MenuItemDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MenuItemFormDialog(initial: initial),
    );
  }

  @override
  State<MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends State<MenuItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;
  late MenuCategory _category;
  late bool _isHalal;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _priceController = TextEditingController(
      text: initial == null ? '' : initial.price.rubles.toStringAsFixed(2),
    );
    _imageUrlController =
        TextEditingController(text: initial?.imageUrl ?? '');
    _category = initial?.category ?? MenuCategory.rolls;
    _isHalal = initial?.isHalal ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final imageUrl = _imageUrlController.text.trim();
    Navigator.of(context).pop(
      MenuItemDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        price: Money.parse(_priceController.text),
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        isHalal: _isHalal,
      ),
    );
  }

  void _previewImage() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Не удалось загрузить изображение'),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'Редактировать блюдо' : 'Новое блюдо',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('menuItemForm.name'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                  textInputAction: TextInputAction.next,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Укажите название'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('menuItemForm.description'),
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Описание / состав',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MenuCategory>(
                        key: const ValueKey('menuItemForm.category'),
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                        ),
                        items: [
                          for (final category in MenuCategory.values)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('menuItemForm.price'),
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Базовая цена, ₽',
                          hintText: '349.90',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9., ]'),
                          ),
                        ],
                        validator: (value) {
                          try {
                            Money.parse(value ?? '');
                            return null;
                          } on FormatException {
                            return 'Некорректная цена';
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('menuItemForm.imageUrl'),
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    labelText: 'URL изображения',
                    suffixIcon: TextButton(
                      key: const ValueKey('menuItemForm.preview'),
                      onPressed: _previewImage,
                      child: const Text('Превью'),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const ValueKey('menuItemForm.halal'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('100% Halal'),
                  subtitle: const Text('Позиция соответствует халяль-стандарту'),
                  value: _isHalal,
                  activeThumbColor: AppColors.halalGreen,
                  onChanged: (value) => setState(() => _isHalal = value),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const ValueKey('menuItemForm.save'),
                      onPressed: _submit,
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
