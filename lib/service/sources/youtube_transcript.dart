import 'dart:convert';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:dio/dio.dart';

/// Video transcript plus the metadata needed to create a book.
class YouTubeTranscript {
  const YouTubeTranscript({
    required this.title,
    required this.author,
    required this.text,
  });

  final String title;
  final String author;
  final String text;
}

const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const _androidClientVersion = '20.10.38';
const _androidUserAgent =
    'com.google.android.youtube/$_androidClientVersion (Linux; U; Android 11) gzip';

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Video id from a watch/short/embed URL or a bare 11-char id.
String? youTubeVideoId(String input) {
  final value = input.trim();
  if (_videoId.hasMatch(value)) return value;

  final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();

  if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
    final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return _videoId.hasMatch(id) ? id : null;
  }
  if (!host.endsWith('youtube.com') && !host.endsWith('youtube-nocookie.com')) {
    return null;
  }

  final queryId = uri.queryParameters['v'];
  if (queryId != null && _videoId.hasMatch(queryId)) return queryId;

  final segments = uri.pathSegments;
  if (segments.length >= 2 &&
      const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
    final id = segments[1];
    return _videoId.hasMatch(id) ? id : null;
  }
  return null;
}

Future<YouTubeTranscript> fetchYouTubeTranscript(String url) async {
  final id = youTubeVideoId(url);
  if (id == null) {
    throw const FormatException('La URL no parece un vídeo de YouTube.');
  }

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  // Key from the app preferences (Settings > YouTube import). When the user has
  // not configured one, the public InnerTube key embedded in the watch page is
  // used; nothing is hardcoded here.
  var apiKey = Prefs().youtubeApiKey.trim();

  Map<String, dynamic>? pagePlayer;
  String? pageTitle;
  String? pageAuthor;

  // 1. Fetch watch page to obtain INNERTUBE_API_KEY and fallback video metadata
  try {
    final page = await dio.get<String>(
      'https://www.youtube.com/watch?v=$id&hl=es',
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'es,en;q=0.8',
        },
      ),
    );
    final html = page.data ?? '';
    if (apiKey.isEmpty) {
      apiKey = RegExp(r'"INNERTUBE_API_KEY":\s*"([a-zA-Z0-9_-]+)"')
              .firstMatch(html)
              ?.group(1) ??
          '';
    }
    pagePlayer = _playerResponse(html);
    if (pagePlayer != null && pagePlayer['videoDetails'] is Map) {
      final details = pagePlayer['videoDetails'] as Map;
      pageTitle = details['title'] as String?;
      pageAuthor = details['author'] as String?;
    }
  } catch (e) {
    AnxLog.warning('YouTube: watch page fetch failed: $e');
  }

  // 2. Query InnerTube API using ANDROID client to bypass web PoToken (&exp=xpe)
  // blocking; fall back to the captions embedded in the watch page.
  Map<String, dynamic>? player;
  if (apiKey.isNotEmpty) {
    player = await _innertubePlayer(dio, apiKey, id);
  }
  player ??= pagePlayer;
  if (player == null) {
    throw const FormatException(
      'YouTube no devolvió los datos del reproductor. Puedes añadir una clave '
      'de API en el importador de YouTube o intentarlo más tarde.',
    );
  }

  final track = youTubeCaptionTrack(player);
  final baseUrl = track?['baseUrl'];
  if (baseUrl is! String || baseUrl.isEmpty) {
    final status = player['playabilityStatus'];
    final reason = status is Map && status['reason'] is String
        ? status['reason'] as String
        : null;
    throw FormatException(
      reason == null
          ? 'Este vídeo no tiene subtítulos disponibles, ni manuales ni automáticos.'
          : 'YouTube no permite descargar este vídeo: $reason',
    );
  }

  final details = player['videoDetails'];
  final title = (details is Map && details['title'] is String)
      ? details['title'] as String
      : (pageTitle ?? 'YouTube $id');
  final author = (details is Map && details['author'] is String)
      ? details['author'] as String
      : (pageAuthor ?? 'YouTube');

  final lines = await _downloadCaptions(dio, baseUrl);
  if (lines.isEmpty) {
    throw const FormatException('Los subtítulos del vídeo están vacíos.');
  }

  AnxLog.info('YouTube: ${lines.length} caption lines for $id');
  return YouTubeTranscript(
    title: title,
    author: author,
    text: YouTubeTranscriptCleaner.clean(lines.join('\n')),
  );
}

/// Extracts `ytInitialPlayerResponse` by walking braces, so quoted braces or
/// nested objects cannot truncate the JSON.
Map<String, dynamic>? _playerResponse(String html) {
  final marker = html.indexOf('ytInitialPlayerResponse');
  if (marker < 0) return null;
  final start = html.indexOf('{', marker);
  if (start < 0) return null;

  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < html.length; i++) {
    final char = html[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) {
        try {
          final decoded = jsonDecode(html.substring(start, i + 1));
          return decoded is Map<String, dynamic> ? decoded : null;
        } catch (e) {
          AnxLog.warning('YouTube: player response parse failed: $e');
          return null;
        }
      }
    }
  }
  return null;
}

/// Caption track for [player]: prefers Spanish or English (manual over auto),
/// then any manual track, then any auto track.
Map<String, dynamic>? youTubeCaptionTrack(Map<String, dynamic> player) {
  final captions = player['captions'];
  if (captions is! Map) return null;
  final renderer = captions['playerCaptionsTracklistRenderer'];
  if (renderer is! Map) return null;
  final tracks = renderer['captionTracks'];
  if (tracks is! List) return null;

  final candidates = tracks
      .whereType<Map>()
      .map((track) => Map<String, dynamic>.from(track))
      .where((track) => track['baseUrl'] is String)
      .toList();
  if (candidates.isEmpty) return null;

  bool isLang(Map<String, dynamic> track, String prefix) {
    final lang = (track['languageCode'] as String? ?? '').toLowerCase();
    return lang == prefix || lang.startsWith('$prefix-');
  }

  // 1. Spanish manual
  for (final t in candidates) {
    if (t['kind'] != 'asr' && isLang(t, 'es')) return t;
  }
  // 2. Spanish auto
  for (final t in candidates) {
    if (isLang(t, 'es')) return t;
  }
  // 3. English manual
  for (final t in candidates) {
    if (t['kind'] != 'asr' && isLang(t, 'en')) return t;
  }
  // 4. English auto
  for (final t in candidates) {
    if (isLang(t, 'en')) return t;
  }
  // 5. Any manual
  for (final t in candidates) {
    if (t['kind'] != 'asr') return t;
  }
  // 6. First candidate
  return candidates.first;
}

/// Asks the InnerTube player endpoint for the video metadata using Android client.
/// Bypasses the Web player's PoToken (&exp=xpe) validation.
Future<Map<String, dynamic>?> _innertubePlayer(
  Dio dio,
  String apiKey,
  String videoId,
) async {
  try {
    final response = await dio.post<Map<String, dynamic>>(
      'https://www.youtube.com/youtubei/v1/player?key=$apiKey',
      data: {
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': _androidClientVersion,
            'hl': 'es',
            'gl': 'ES',
          },
        },
        'videoId': videoId,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'User-Agent': _androidUserAgent,
        },
      ),
    );
    return response.data;
  } catch (e) {
    AnxLog.warning('YouTube: innertube player failed: $e');
    return null;
  }
}

/// Downloads the caption track using Android client headers to avoid 0-byte throttling.
Future<List<String>> _downloadCaptions(Dio dio, String baseUrl) async {
  final plain = baseUrl.replaceAll(RegExp(r'&fmt=[^&]*'), '');
  for (final url in <String>[plain, '$plain&fmt=json3']) {
    try {
      final response = await dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'User-Agent': _androidUserAgent},
        ),
      );
      final lines = _linesFromTimedText(response.data ?? '');
      if (lines.isNotEmpty) return lines;
    } catch (e) {
      AnxLog.warning('YouTube: caption download failed: $e');
    }
  }
  return const [];
}

List<String> _linesFromTimedText(String body) {
  if (body.trim().isEmpty) return const [];
  final jsonLines = _linesFromJson(body);
  if (jsonLines.isNotEmpty) return jsonLines;
  return _linesFromXml(body);
}

List<String> _linesFromJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const [];
    final events = decoded['events'];
    if (events is! List) return const [];

    final lines = <String>[];
    for (final event in events) {
      if (event is! Map) continue;
      final segs = event['segs'];
      if (segs is! List) continue;
      final buffer = StringBuffer();
      for (final seg in segs) {
        if (seg is Map && seg['utf8'] is String) {
          buffer.write(seg['utf8']);
        }
      }
      final line = buffer.toString().trim();
      if (line.isNotEmpty) lines.add(line);
    }
    return lines;
  } catch (e) {
    AnxLog.warning('YouTube: timed text parse failed: $e');
    return const [];
  }
}

/// Some tracks only answer with the classic timedtext XML.
List<String> _linesFromXml(String body) {
  final lines = <String>[];
  for (final match in _textTag.allMatches(body)) {
    final text = (match.group(1) ?? '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isNotEmpty) lines.add(text);
  }
  return lines;
}

final _textTag = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true);

/// Turns raw captions into book-like prose: drops timestamps, bracketed sound
/// cues such as [Música], sound parentheses such as (risas), speaker tags and
/// the repeated lines of rolling auto-captions.
class YouTubeTranscriptCleaner {
  static final RegExp _timestamps =
      RegExp(r'(\d{1,2}:)?\d{1,2}:\d{2}([.,]\d{1,3})?');
  static final RegExp _bracketed = RegExp(r'\[[^\]]*\]');
  static final RegExp _parenthetical = RegExp(r'\(([^()]{1,40})\)');
  static final RegExp _soundCue = RegExp(
    r'\b(m[uú]sica|risas|aplausos|sonido|ruido|tos|tose|suspira|jadea|'
    r'inaudible|silencio|applause|laughter|music|noise|coughs|laughs|'
    r'silence)\b',
    caseSensitive: false,
  );
  static final RegExp _arrows = RegExp(r'^.*-->.*$', multiLine: true);
  static final RegExp _speakerMarks = RegExp(r'^\s*>>\s*');
  static final RegExp _spaceBeforePunctuation = RegExp(r'\s+([.,;:!?…])');
  static final RegExp _sentenceEnd = RegExp(r'(?<=[.!?…])\s+');

  /// Target paragraph length; captions have no paragraphs of their own.
  static const int _paragraphChars = 420;

  static String clean(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(_arrows, ' ');
    text = text.replaceAll(_bracketed, ' ');
    text = text.replaceAllMapped(
      _parenthetical,
      (match) => _soundCue.hasMatch(match.group(1) ?? '') ? ' ' : match.group(0)!,
    );
    text = text.replaceAll(_timestamps, ' ');
    text = text.replaceAllMapped(
      _spaceBeforePunctuation,
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    final lines = <String>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.replaceAll(_speakerMarks, '').trim();
      if (line.isEmpty) continue;
      if (lines.isNotEmpty && lines.last == line) continue;
      lines.add(line);
    }

    final sentences = <String>[];
    for (final rawSentence in lines.join(' ').split(_sentenceEnd)) {
      final sentence = rawSentence.trim();
      if (sentence.length < 2) continue;
      if (sentences.isNotEmpty && sentences.last == sentence) continue;
      sentences.add(sentence);
    }

    final paragraphs = <String>[];
    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
      if (buffer.length >= _paragraphChars) {
        paragraphs.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) paragraphs.add(buffer.toString());
    return paragraphs.join('\n');
  }
}
