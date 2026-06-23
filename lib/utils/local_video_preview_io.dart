import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Превью видео из байтов (временный файл + [VideoPlayerController.file]).
class LocalVideoPreviewHandle {
  LocalVideoPreviewHandle._(this.controller, this._filePath);

  final VideoPlayerController controller;
  final String _filePath;

  static Future<LocalVideoPreviewHandle> open(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final ext = _ext(filename);
    final path = '${dir.path}/dastrass_vid_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    final c = VideoPlayerController.file(file);
    await c.initialize();
    return LocalVideoPreviewHandle._(c, path);
  }

  static Future<void> close(LocalVideoPreviewHandle? h) async {
    if (h == null) return;
    await h.controller.dispose();
    try {
      final f = File(h._filePath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i >= name.length - 1) return 'mp4';
    final e = name.substring(i + 1).toLowerCase();
    return e.length > 8 ? 'mp4' : e;
  }
}
