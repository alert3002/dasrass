// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:video_player/video_player.dart';

/// Превью видео в браузере: blob: URL + [VideoPlayerController.networkUrl].
class LocalVideoPreviewHandle {
  LocalVideoPreviewHandle._(this.controller, this._blobUrl);

  final VideoPlayerController controller;
  final String _blobUrl;

  static Future<LocalVideoPreviewHandle> open(Uint8List bytes, String filename) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    await c.initialize();
    return LocalVideoPreviewHandle._(c, url);
  }

  static Future<void> close(LocalVideoPreviewHandle? h) async {
    if (h == null) return;
    await h.controller.dispose();
    try {
      html.Url.revokeObjectUrl(h._blobUrl);
    } catch (_) {}
  }
}
