import 'package:anx_reader/utils/log/common.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;

/// Centralized, re-entrancy-safe wrapper around the platform file picker.
///
/// On every platform this delegates to `FilePicker.platform`, which on Android
/// launches the **native** system document picker
/// (`ACTION_OPEN_DOCUMENT` / `ACTION_GET_CONTENT`) through the plugin's method
/// channel — the same picker used by other Android apps.
///
/// The Android plugin throws `PlatformException(already_active)` when a picker
/// is launched while another dialog is still open, which happens easily on
/// rapid multiple taps and leaves the picker unusable afterwards. This wrapper
/// ignores re-entrant calls and swallows that specific exception, so extra taps
/// are harmless instead of crashing or blocking the picker.
class AnxFilePicker {
  AnxFilePicker._();

  static bool _isPicking = false;

  /// Whether a picker dialog is currently open.
  static bool get isPicking => _isPicking;

  static Future<T> _guarded<T>(
    Future<T> Function() action,
    T fallback,
  ) async {
    if (_isPicking) {
      AnxLog.info('AnxFilePicker: ignored re-entrant picker call');
      return fallback;
    }
    _isPicking = true;
    try {
      return await action();
    } on PlatformException catch (e) {
      if (e.code == 'already_active') {
        AnxLog.info('AnxFilePicker: native picker already active, ignored');
        return fallback;
      }
      rethrow;
    } finally {
      _isPicking = false;
    }
  }

  /// Opens the native file picker. Returns null if the user cancels or if a
  /// picker is already open (e.g. duplicate taps).
  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
  }) {
    return _guarded<FilePickerResult?>(
      () => FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: withData,
      ),
      null,
    );
  }

  /// Opens the native directory picker. Returns null if the user cancels or if
  /// a picker is already open.
  static Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
  }) {
    return _guarded<String?>(
      () => FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
      ),
      null,
    );
  }
}
