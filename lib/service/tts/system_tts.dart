import 'dart:async';
import 'package:anx_reader/utils/platform_utils.dart';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/page/reading_page.dart';
import 'package:anx_reader/service/tts/base_tts.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_service.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SystemTts extends BaseTts {
  static final SystemTts _instance = SystemTts._internal();

  factory SystemTts() {
    return _instance;
  }

  SystemTts._internal();

  final FlutterTts flutterTts = FlutterTts();

  String? _currentVoiceText;
  static String? _prevVoiceText;

  /// El motor TTS de Android ya está inicializado (evita llamadas de nuevo).
  bool _androidEngineReady = false;

  bool restarting = false;

  late Function getHereFunction;
  late Function getNextTextFunction;
  late Function getPrevTextFunction;

  @override
  final ValueNotifier<TtsStateEnum> ttsStateNotifier =
      ValueNotifier<TtsStateEnum>(TtsStateEnum.stopped);

  @override
  void updateTtsState(TtsStateEnum newState) {
    ttsStateNotifier.value = newState;
  }

  bool get isIOS => AnxPlatform.isIOS;
  bool get isAndroid => AnxPlatform.isAndroid;
  bool get isWindows => AnxPlatform.isWindows;
  bool get isLinux => AnxPlatform.isLinux;
  bool get isWeb => kIsWeb;

  @override
  double get volume => Prefs().ttsVolume;

  @override
  set volume(double volume) {
    Prefs().ttsVolume = volume;
    restart();
  }

  @override
  double get pitch => Prefs().ttsPitch;

  @override
  set pitch(double pitch) {
    Prefs().ttsPitch = pitch;
    restart();
  }

  @override
  double get rate => Prefs().ttsRate;

  @override
  set rate(double rate) {
    Prefs().ttsRate = rate;
    restart();
  }

  @override
  bool get isPlaying => ttsStateNotifier.value == TtsStateEnum.playing;

  @override
  String? get currentVoiceText => _currentVoiceText;

  @override
  Future<void> init(Function getCurrentText, Function getNextText,
      Function getPrevText) async {
    getHereFunction = getCurrentText;
    getNextTextFunction = getNextText;
    getPrevTextFunction = getPrevText;

    if (isLinux) {
      return;
    }

    await setAwaitOptions();

    if (isAndroid) {
      await getDefaultEngine();
      await getDefaultVoice();
    }

    flutterTts.setStartHandler(() async {
      updateTtsState(TtsStateEnum.playing);
      if (!isAndroid) {
        return;
      }
      _prevVoiceText = _currentVoiceText;
      _currentVoiceText = await epubPlayerKey.currentState!.ttsPrepare();

      if (_currentVoiceText?.isNotEmpty ?? false) {
        flutterTts.speak(_currentVoiceText!);
      }
    });

    flutterTts.setCompletionHandler(() async {
      if (!isAndroid) {
        return;
      }
      updateTtsState(TtsStateEnum.playing);
      if (_currentVoiceText?.isEmpty ?? true) {
        _currentVoiceText = await getNextText();
        await speak();
      } else {
        await getNextText();
      }
    });
  }

  Future<void> setAwaitOptions() async {
    if (isLinux) {
      return;
    }
    await flutterTts.awaitSpeakCompletion(true);
    if (isAndroid) {
      await flutterTts.awaitSynthCompletion(true);
      await flutterTts.setQueueMode(1);
    }
  }

  Future<void> getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {}
  }

  Future<void> getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {}
  }

  /// Apply the voice by shortName
  Future<void> _applyVoice(String? voiceShortName) async {
    try {
      // Get all voices to find the matching one
      final voices = await flutterTts.getVoices;
      if (voices is List) {
        for (var voice in voices) {
          final map = Map<String, dynamic>.from(voice);
          if (map['name'] == voiceShortName) {
            // flutter_tts setVoice expects a Map with 'name' and 'locale'
            await flutterTts.setVoice({
              'name': map['name'],
              'locale': map['locale'],
            });
            return;
          }
        }
        // No hay voz guardada: se usa la mejor voz en español disponible.
        final fallback = _pickSpanishVoice(voices);
        if (fallback != null) {
          await flutterTts.setVoice({
            'name': fallback['name'],
            'locale': fallback['locale'],
          });
        }
      }
    } catch (e) {
      // Fallback: try to set voice directly (some platforms support this)
      // Ignore errors if voice not found
    }
  }

  /// For testing a specific voice in settings (matching OnlineTts API)
  Future<void> speakWithVoice(String content, String voiceShortName) async {
    if (isLinux) {
      return;
    }
    await stop();
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);
    await _applyVoice(voiceShortName);
    await flutterTts.speak(content);
  }

  @override
  Future<void> speak({String? content}) async {
    if (isLinux) {
      return;
    }
    await setAwaitOptions();
    if (content != null) {
      _currentVoiceText = content;
    }
    if (_currentVoiceText == null) {
      // getHereFunction() is initTts() — it initialises the JS TTS position
      // but returns void.  Fetch the actual first sentence via getNextTextFunction.
      await getHereFunction();
      _currentVoiceText = await getNextTextFunction();
    }

    // Guard: if still null or empty (e.g. WebView not ready), abort.
    if (_currentVoiceText == null || _currentVoiceText!.isEmpty) {
      return;
    }

    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    // Apply the saved voice model
    String? selectedVoice;
    try {
      selectedVoice = SystemTtsProvider().resolveVoice(null);
    } catch (_) {
      // Sin voz seleccionada se usa la voz por defecto del motor.
      selectedVoice = null;
    }
    await _applyVoice(selectedVoice);

    await flutterTts.speak(_currentVoiceText!);

    if (!isAndroid && ttsStateNotifier.value == TtsStateEnum.playing) {
      _currentVoiceText = await getNextTextFunction();
      speak();
    }
  }

  @override
  Future<dynamic> stop() async {
    updateTtsState(TtsStateEnum.stopped);
    if (isLinux) {
      _currentVoiceText = null;
      return null;
    }
    final result = await _ignoreMissingPlugin(() => flutterTts.stop());
    _currentVoiceText = null;
    return result;
  }

  @override
  Future<void> pause() async {
    if (isLinux) {
      updateTtsState(TtsStateEnum.paused);
      return;
    }
    final result = await _ignoreMissingPlugin(() => flutterTts.stop());
    if (result == 1) {
      updateTtsState(TtsStateEnum.paused);
    }
  }

  @override
  Future<void> resume() async {
    if (isLinux) {
      return;
    }
    if (isAndroid) {
      speak(content: _prevVoiceText);
      return;
    }
    speak(content: _currentVoiceText);
  }

  @override
  Future<void> prev() async {
    if (restarting) {
      return;
    }
    restarting = true;
    await stop();
    _currentVoiceText = await getPrevTextFunction();
    speak();
    restarting = false;
  }

  @override
  Future<void> next() async {
    if (restarting) {
      return;
    }
    restarting = true;
    await stop();
    _currentVoiceText = await getNextTextFunction();
    speak();
    restarting = false;
  }

  @override
  Future<void> restart() async {
    if (restarting) {
      return;
    }
    restarting = true;
    await stop();
    speak();
    restarting = false;
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    if (isLinux) {
      return [];
    }
    try {
      await _ensureAndroidEngine();

      dynamic voices = await flutterTts.getVoices;

      // En Android el motor puede terminar de inicializar tarde: si la lista
      // viene vacía se reintenta una vez.
      if ((voices is! List || voices.isEmpty) && isAndroid) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _ensureAndroidEngine(force: true);
        voices = await flutterTts.getVoices;
      }

      if (voices is List) {
        final list = voices.map((e) {
          final map = Map<String, dynamic>.from(e);
          return TtsVoice(
              shortName: map['name'] ?? '',
              name: map['name'] ?? '',
              locale: map['locale']?.replaceAll('_', '-') ?? '',
              gender: map['gender']?.toString().toLowerCase() ?? '',
              rawData: map);
        }).toList();
        return _sortVoices(list);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Android solo devuelve las voces cuando el motor TTS está inicializado.
  Future<void> _ensureAndroidEngine({bool force = false}) async {
    if (!isAndroid) return;
    if (_androidEngineReady && !force) return;
    try {
      final engine = await flutterTts.getDefaultEngine;
      if (engine is String && engine.isNotEmpty) {
        await flutterTts.setEngine(engine);
      }
      await flutterTts.setSharedInstance(true);
    } catch (e) {
      AnxLog.warning('System TTS engine initialization failed: $e');
    }
    _androidEngineReady = true;
  }

  /// Prioriza las voces en español (es-ES, es-MX, es-US) y el resto por locale.
  static List<TtsVoice> _sortVoices(List<TtsVoice> voices) {
    final sorted = [...voices];
    sorted.sort((a, b) {
      final priority = _voicePriority(a).compareTo(_voicePriority(b));
      if (priority != 0) return priority;
      final locale = a.locale.compareTo(b.locale);
      if (locale != 0) return locale;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  static const _spanishPriority = ['es-ES', 'es-MX', 'es-US'];

  static int _voicePriority(TtsVoice voice) {
    final locale = voice.locale;
    final index = _spanishPriority.indexOf(locale);
    if (index >= 0) return index;
    if (locale.toLowerCase().startsWith('es')) return _spanishPriority.length;
    return _spanishPriority.length + 1;
  }

  /// Devuelve la mejor voz en español de la lista del motor.
  static Map<String, dynamic>? _pickSpanishVoice(dynamic voices) {
    if (voices is! List) return null;
    Map<String, dynamic>? best;
    var bestPriority = 1 << 20;
    for (final voice in voices) {
      final map = Map<String, dynamic>.from(voice);
      final locale = (map['locale']?.toString() ?? '').replaceAll('_', '-');
      final index = _spanishPriority.indexOf(locale);
      final priority = index >= 0
          ? index
          : (locale.toLowerCase().startsWith('es')
              ? _spanishPriority.length
              : _spanishPriority.length + 1);
      if (priority < bestPriority) {
        bestPriority = priority;
        best = map;
      }
    }
    if (best == null) return null;
    if (bestPriority > _spanishPriority.length) return null;
    return best;
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  Future<T?> _ignoreMissingPlugin<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      return null;
    }
  }
}
