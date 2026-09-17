import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../cubit/menu_image_upload_cubit.dart';
import '../../cubit/menu_image_upload_state.dart';
import '../../data/menu_image_picker.dart';
import 'menu_item_image.dart';

class MenuImageUploadField extends StatelessWidget {
  const MenuImageUploadField({
    super.key,
    required this.cubit,
    required this.controller,
  });
  final MenuImageUploadCubit cubit;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MenuImageUploadCubit, MenuImageUploadState>(
        bloc: cubit,
        listener: (context, state) {
          if (state.status == MenuImageUploadStatus.success) {
            controller.text = state.url!;
          }
          if (state.status == MenuImageUploadStatus.failure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          }
        },
        builder: (context, state) => Column(
          children: [
            DropTarget(
              enable: !state.isBusy,
              onDragDone: (details) {
                if (details.files.length != 1 ||
                    details.files.single is DropItemDirectory) {
                  cubit.rejectDrop();
                  return;
                }
                final file = details.files.single;
                cubit.drop(
                  MenuImageFile(
                    name: file.name,
                    length: file.length,
                    read: file.readAsBytes,
                  ),
                );
              },
              child: OutlinedButton(
                key: const ValueKey('menuImage.pick'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.terracotta,
                  side: const BorderSide(color: AppColors.terracotta),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: state.isBusy ? null : cubit.pick,
                child: const SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                    child: Column(
                      children: [
                        Icon(Icons.add_photo_alternate_outlined),
                        Text(
                          'Перетащите изображение сюда',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'или нажмите для выбора файла',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'JPG, PNG, WebP · до 15 МБ · 1:1',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (state.isBusy) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.progress,
                color: AppColors.terracotta,
              ),
              Text(
                state.status == MenuImageUploadStatus.picking
                    ? 'Выбор изображения…'
                    : state.progress == 1
                    ? 'Обработка изображения…'
                    : 'Загрузка изображения…',
              ),
            ],
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.trim().isEmpty) return const SizedBox.shrink();
                String? url;
                try {
                  url = cubit.resolveUrl(value.text.trim());
                } catch (_) {
                  /* Invalid manual URLs use the placeholder. */
                }
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    MenuItemImage(imageUrl: url, size: 200),
                    TextButton.icon(
                      key: const ValueKey('menuImage.remove'),
                      onPressed: state.isBusy
                          ? null
                          : () {
                              controller.clear();
                              cubit.clear();
                            },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить фото'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}
