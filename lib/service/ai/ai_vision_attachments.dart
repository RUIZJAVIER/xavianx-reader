import 'dart:io';
import 'dart:typed_data';

import 'package:anx_reader/service/ai/ai_vision_support.dart';
import 'package:anx_reader/utils/get_path/get_cache_dir.dart';

/// Stores the screenshots attached to AI chat messages on disk so they can be
/// persisted with the conversation history without bloating the history JSON
/// with base64 payloads.
class AiVisionAttachments {
  AiVisionAttachments._();

  static const String folderName = 'ai_screenshots';

  static Future<Directory> _folder() async {
    final cacheDir = await getAnxCacheDir();
    final dir = Directory(
      '${cacheDir.path}${Platform.pathSeparator}$folderName',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Persists [bytes] and returns the absolute file path.
  ///
  /// The image is resized/compressed first so history backups and future
  /// vision requests stay small.
  static Future<String> save(Uint8List bytes) async {
    final prepared = AiVisionSupport.prepareImageForVision(bytes);
    final dir = await _folder();
    final name = 'shot_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(prepared, flush: true);
    return file.path;
  }

  static Future<Uint8List?> read(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  static Future<void> clearAll() async {
    try {
      final cacheDir = await getAnxCacheDir();
      final dir = Directory(
        '${cacheDir.path}${Platform.pathSeparator}$folderName',
      );
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
