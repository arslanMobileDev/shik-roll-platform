import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Lazy file access shared by the native picker and browser drop target.
class MenuImageFile {
  const MenuImageFile({
    required this.name,
    required this.length,
    required this.read,
  });
  final String name;
  final Future<int?> Function() length;
  final Future<Uint8List> Function() read;
}

class MenuImagePicker {
  Future<MenuImageFile?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return null;
    return MenuImageFile(
      name: file.name,
      length: file.length,
      read: file.readAsBytes,
    );
  }
}
