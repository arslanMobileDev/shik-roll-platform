import 'package:equatable/equatable.dart';

enum MenuImageUploadStatus { idle, picking, uploading, success, failure }

class MenuImageUploadState extends Equatable {
  const MenuImageUploadState({
    this.status = MenuImageUploadStatus.idle,
    this.url,
    this.progress,
    this.message,
  });
  final MenuImageUploadStatus status;
  final String? url;
  final double? progress;
  final String? message;
  bool get isBusy =>
      status == MenuImageUploadStatus.picking ||
      status == MenuImageUploadStatus.uploading;
  @override
  List<Object?> get props => [status, url, progress, message];
}
