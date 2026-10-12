import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/menu_image_upload_cubit.dart';
import '../../cubit/menu_image_upload_state.dart';
import 'menu_image_upload_field.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../data/models/menu_category_ref.dart';
import '../../data/models/menu_item.dart';

/// Opens the category dialog from inside this form; returns the saved category,
/// or `null` when the manager backs out.
typedef CreateCategoryCallback = Future<MenuCategoryRef?> Function();

/// Modal create/edit form for a catalog position.
///
/// Pops with a [MenuItemDraft] on successful validation, `null` on cancel.
class MenuItemFormDialog extends StatefulWidget {
  const MenuItemFormDialog({
    super.key,
    required this.categories,
    this.initial,
    this.uploadCubit,
    this.onCreateCategory,
  });

  /// When non-null the dialog edits this item instead of creating one.
  final MenuItem? initial;

  /// Categories of the active menu: the dropdown's options and the source of
  /// the `categoryId` the API expects.
  final List<MenuCategoryRef> categories;
  final MenuImageUploadCubit? uploadCubit;

  /// Backs the trailing "+ Создать новую категорию" entry. The caller supplies
  /// it because the dialog route sits above the bloc provider and cannot reach
  /// it itself; without it the entry is not offered.
  final CreateCategoryCallback? onCreateCategory;

  static Future<MenuItemDraft?> show(
    BuildContext context, {
    required List<MenuCategoryRef> categories,
    MenuItem? initial,
    CreateCategoryCallback? onCreateCategory,
  }) {
    return showDialog<MenuItemDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MenuItemFormDialog(
        initial: initial,
        categories: categories,
        onCreateCategory: onCreateCategory,
      ),
    );
  }

  @override
  State<MenuItemFormDialog> createState() => _MenuItemFormDialogState();
}

class _MenuItemFormDialogState extends State<MenuItemFormDialog> {
  /// Dropdown value of the "+ Создать новую категорию" entry. Never reaches
  /// [_categoryId], so it cannot end up in the payload.
  static const _createCategoryValue = '__create_category__';

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _allergensController;
  late final MenuImageUploadCubit _uploadCubit;
  late final List<MenuCategoryRef> _categories;
  String? _categoryId;
  late bool _isHalal;

  /// Bumped whenever the dropdown's selection is set from code. The underlying
  /// `FormField` never re-reads `initialValue` on rebuild (flutter's
  /// `FormFieldState.didUpdateWidget` ignores it), so without a fresh key the
  /// "+ Создать новую категорию" entry would stay on screen as the selection.
  int _categoryFieldEpoch = 0;

  bool get _isEditing => widget.initial != null;

  /// Menu categories (including ones created from this dialog), plus the edited
  /// item's own category when it is not part of the active menu — otherwise the
  /// dropdown would have no matching option and silently reassign the dish on
  /// the next save.
  List<({String id, String name})> get _categoryOptions {
    final options = [
      for (final category in _categories)
        (id: category.id, name: category.name),
    ];
    final currentId = widget.initial?.categoryId;
    if (currentId != null && !options.any((option) => option.id == currentId)) {
      options.insert(
        0,
        (id: currentId, name: widget.initial!.categoryName),
      );
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _categories = [...widget.categories];
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _priceController = TextEditingController(
      text: initial == null ? '' : initial.price.rubles.toStringAsFixed(2),
    );
    _imageUrlController = TextEditingController(text: initial?.imageUrl ?? '');
    _allergensController = TextEditingController(
      text: initial?.allergens ?? '',
    );
    _uploadCubit =
        widget.uploadCubit ??
        MenuImageUploadCubit(initialUrl: initial?.imageUrl);
    _categoryId = initial?.categoryId;
    _isHalal = initial?.isHalal ?? true;
  }

  @override
  void dispose() {
    if (widget.uploadCubit == null) _uploadCubit.close();
    _allergensController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_uploadCubit.state.isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final imageUrl = _imageUrlController.text.trim();
    Navigator.of(context).pop(
      MenuItemDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: _categoryId!,
        price: Money.parse(_priceController.text),
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        allergens: _allergensController.text.trim().isEmpty
            ? null
            : _allergensController.text.trim(),
        isHalal: _isHalal,
      ),
    );
  }

  /// Delegates to the caller's category dialog and adopts the result, so the
  /// dish ends up in the category the manager just created. A cancelled dialog
  /// leaves the previous selection alone.
  Future<void> _createCategory() async {
    final create = widget.onCreateCategory;
    if (create == null) return;
    final created = await create();
    if (!mounted) return;
    setState(() {
      if (created != null) {
        _categories.add(created);
        _categoryId = created.id;
      }
      _categoryFieldEpoch++;
    });
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

  bool get _isMobile =>
      AppBreakpoints.isMobile(MediaQuery.sizeOf(context).width);

  /// Category picker: a full-width field of its own on phones, half of a pair
  /// on desktop.
  Widget _categoryField() {
    return KeyedSubtree(
      key: ValueKey('menuItemForm.category.$_categoryFieldEpoch'),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('menuItemForm.category'),
        initialValue: _categoryId,
        // The trailing "create" entry is wider than the field; without this
        // the row overflows.
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Категория'),
        items: [
          for (final option in _categoryOptions)
            DropdownMenuItem(
              value: option.id,
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
          if (widget.onCreateCategory != null)
            const DropdownMenuItem(
              value: _createCategoryValue,
              child: Text(
                '+ Создать новую категорию',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        validator: (value) => value == null || value == _createCategoryValue
            ? 'Выберите категорию'
            : null,
        onChanged: (value) {
          if (value == _createCategoryValue) {
            unawaited(_createCategory());
            return;
          }
          setState(() => _categoryId = value);
        },
      ),
    );
  }

  Widget _priceField() {
    return TextFormField(
      key: const ValueKey('menuItemForm.price'),
      controller: _priceController,
      decoration: const InputDecoration(
        labelText: 'Базовая цена, ₽',
        hintText: '349.90',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
      validator: (value) {
        try {
          Money.parse(value ?? '');
          return null;
        } on FormatException {
          return 'Некорректная цена';
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuImageUploadCubit, MenuImageUploadState>(
      bloc: _uploadCubit,
      builder: (context, uploadState) => Dialog(
        backgroundColor: Colors.white,
        // +56px of usable width on a phone.
        insetPadding: _isMobile
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
            : null,
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
                  if (_isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _categoryField(),
                        const SizedBox(height: 12),
                        _priceField(),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _categoryField()),
                        const SizedBox(width: 12),
                        Expanded(child: _priceField()),
                      ],
                    ),
                  const SizedBox(height: 12),
                  MenuImageUploadField(
                    cubit: _uploadCubit,
                    controller: _imageUrlController,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('menuItemForm.allergens'),
                    controller: _allergensController,
                    decoration: const InputDecoration(
                      labelText: 'Аллергены',
                      hintText: 'Глютен, лактоза, соя…',
                    ),
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 500,
                    validator: (value) => (value?.length ?? 0) > 500
                        ? 'Не более 500 символов'
                        : null,
                  ),
                  TextFormField(
                    key: const ValueKey('menuItemForm.imageUrl'),
                    enabled: !uploadState.isBusy,
                    validator: (value) => (value?.trim().length ?? 0) > 500
                        ? 'Не более 500 символов'
                        : null,
                    controller: _imageUrlController,
                    decoration: InputDecoration(
                      labelText: 'или вставьте URL',
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
                    subtitle: const Text(
                      'Позиция соответствует халяль-стандарту',
                    ),
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
                        onPressed: uploadState.isBusy ? null : _submit,
                        child: Text(_isEditing ? 'Сохранить' : 'Создать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
