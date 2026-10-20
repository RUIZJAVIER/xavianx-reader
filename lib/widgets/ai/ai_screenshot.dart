import 'dart:io';
import 'dart:typed_data';

import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/service/ai/ai_vision_support.dart';
import 'package:anx_reader/utils/pick_file.dart';
import 'package:file_picker/file_picker.dart';

/// Helpers used by the AI vision features to obtain screenshot bytes.
class AiScreenshot {
  AiScreenshot._();

  /// Whether a reading screen is currently mounted and can be captured.
  static bool get canCaptureReading {
    try {
      return epubPlayerKey.currentState?.webViewController != null;
    } catch (_) {
      return false;
    }
  }

  /// Captures the currently visible reading viewport (the book page rendered in
  /// the webview) as PNG bytes. Returns null when unavailable (e.g. Linux CEF)
  /// or when no reading page is open.
  static Future<Uint8List?> captureReading() async {
    try {
      final controller = epubPlayerKey.currentState?.webViewController;
      if (controller == null) {
        return null;
      }
      final bytes = await controller.takeScreenshot();
      return bytes == null ? null : AiVisionSupport.prepareImageForVision(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Lets the user pick an image file (notes, photos, ...) from the device.
  static Future<Uint8List?> pickImage() async {
    final result = await AnxFilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes != null) {
      return AiVisionSupport.prepareImageForVision(bytes);
    }
    final path = file.path;
    if (path != null) {
      try {
        final picked = await File(path).readAsBytes();
        return AiVisionSupport.prepareImageForVision(picked);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
