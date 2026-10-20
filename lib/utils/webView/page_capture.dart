import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/utils/webView/epub_webview_controller.dart';
import 'package:flutter/foundation.dart';

/// Captures the visible reading page as image bytes.
///
/// PDF pages are read straight from the PDF.js `<canvas>`. Android cannot
/// capture the WebView hardware surface (`RepaintBoundary.toImage()` returns a
/// blank bitmap), so a native screenshot would hand a white image to the AI.
/// HTML views (EPUB, FB2, ...) keep using the WebView screenshot.
Future<Uint8List?> captureVisiblePage(EpubWebViewController controller) async {
  final canvasBytes = await capturePdfCanvas(controller);
  if (canvasBytes != null && canvasBytes.isNotEmpty) {
    return canvasBytes;
  }
  try {
    return await controller.takeScreenshot();
  } catch (e) {
    debugPrint('captureVisiblePage failed: $e');
    return null;
  }
}

/// Asks the PDF viewer for the visible part of the active page canvas.
///
/// `anxCaptureVisiblePage()` returns a `data:image/jpeg;base64,...` string, or
/// an empty string when the open book is not a PDF (or has no canvas yet).
Future<Uint8List?> capturePdfCanvas(EpubWebViewController controller) async {
  try {
    final result = await controller.evaluate(
      'typeof anxCaptureVisiblePage === "function"'
      ' ? anxCaptureVisiblePage() : ""',
    );
    if (result is! String || result.isEmpty) {
      return null;
    }
    final comma = result.indexOf(',');
    if (comma < 0) {
      return null;
    }
    return base64Decode(result.substring(comma + 1));
  } catch (e) {
    debugPrint('capturePdfCanvas failed: $e');
    return null;
  }
}
