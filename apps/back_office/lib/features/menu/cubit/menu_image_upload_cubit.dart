import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/menu_image_picker.dart';
import '../data/menu_image_upload_repository.dart';
import 'menu_image_upload_state.dart';

class MenuImageUploadCubit extends Cubit<MenuImageUploadState> {
  MenuImageUploadCubit({
    MenuImagePicker? picker,
    MenuImageUploadRepository? repository,
    String? initialUrl,
  }) : _picker = picker ?? MenuImagePicker(),
       _repository = repository ?? MenuImageUploadRepository(),
       super(MenuImageUploadState(url: initialUrl));
  final MenuImagePicker _picker;
  final MenuImageUploadRepository _repository;
  CancelToken? _cancelToken;

  String resolveUrl(String value) => _repository.resolveUrl(value);

  Future<void> pick() async {
    if (state.isBusy || isClosed) return;
    emit(
      MenuImageUploadState(
        status: MenuImageUploadStatus.picking,
        url: state.url,
      ),
    );
    try {
      final file = await _picker.pick();
      if (isClosed) return;
      if (file == null) {
        emit(MenuImageUploadState(url: state.url));
        return;
      }
      await _upload(file);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> drop(MenuImageFile file) async {
    if (state.isBusy || isClosed) return;
    await _upload(file);
  }

  void rejectDrop() {
    if (!state.isBusy && !isClosed) {
      _fail(
        const MenuImageUploadException(
          'Перетащите один файл JPG, PNG или WebP',
        ),
      );
    }
  }

  Future<void> _upload(MenuImageFile file) async {
    final previousUrl = state.url;
    _cancelToken = CancelToken();
    emit(
      MenuImageUploadState(
        status: MenuImageUploadStatus.uploading,
        url: previousUrl,
      ),
    );
    try {
      final url = await _repository.upload(
        file,
        cancelToken: _cancelToken!,
        onProgress: (sent, total) {
          if (!isClosed) {
            emit(
              MenuImageUploadState(
                status: MenuImageUploadStatus.uploading,
                url: previousUrl,
                progress: total > 0 ? (sent / total).clamp(0.0, 1.0) : null,
              ),
            );
          }
        },
      );
      if (!isClosed) {
        emit(
          MenuImageUploadState(status: MenuImageUploadStatus.success, url: url),
        );
      }
    } catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    if (!isClosed) {
      emit(
        MenuImageUploadState(
          status: MenuImageUploadStatus.failure,
          url: state.url,
          message: error is MenuImageUploadException
              ? error.message
              : 'Не удалось прочитать изображение. Выберите файл повторно',
        ),
      );
    }
  }

  void clear() {
    if (!state.isBusy && !isClosed) emit(const MenuImageUploadState());
  }

  @override
  Future<void> close() {
    _cancelToken?.cancel();
    return super.close();
  }
}
