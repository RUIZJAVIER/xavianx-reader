import 'dart:convert';

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
      headers: {'User-Agent': _userAgent, 'Accept-Language': 'es,en;q=0.8'},
    ),
  );

  // bpctr/has_verified skip the EU consent interstitial that hides captions.
  final page = await dio.get<String>(
    'https://www.youtube.com/watch?v=$id&hl=en&has_verified=1&bpctr=9999999999',
    options: Options(responseType: ResponseType.plain),
  );
  final html = page.data ?? '';
  var player = _playerResponse(html);
  player ??= await _innertubePlayer(dio, html, id);
  if (player == null) {
    throw const FormatException(
      'YouTube no devolvió los datos del reproductor. Revisa la URL o '
      'inténtalo más tarde.',
    );
  }

  var track = youTubeCaptionTrack(player);
  if (track == null) {
    // The watch page sometimes ships a player response without captions; the
    // InnerTube player endpoint still returns manual and auto-generated (ASR)
    // tracks, which is what most videos have.
    final fallback = await _innertubePlayer(dio, html, id);
    if (fallback != null) {
      player = fallback;
      track = youTubeCaptionTrack(fallback);
    }
  }

  final baseUrl = track?['baseUrl'];
  if (baseUrl is! String || baseUrl.isEmpty) {
    final status = player['playabilityStatus'];
    final reason = status is Map && status['reason'] is String
        ? status['reason'] as String
        : null;
    throw FormatException(
      reason == null
          ? 'Este vídeo no tiene subtítulos, ni manuales ni automáticos.'
          : 'YouTube no permite descargar este vídeo: $reason',
    );
  }

  final details = player['videoDetails'];
  final title = details is Map && details['title'] is String
      ? details['title'] as String
      : 'YouTube $id';
  final author = details is Map && details['author'] is String
      ? details['author'] as String
      : 'YouTube';

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

/// Caption track for [player]: a manually written one when the video has it,
/// and the auto-generated (ASR) track otherwise.
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

  for (final track in candidates) {
    if (track['kind'] != 'asr') return track;
  }
  return candidates.first;
}

/// Asks the InnerTube player endpoint for the video metadata. Unlike the watch
/// page, it usually reports auto-generated caption tracks as well.
Future<Map<String, dynamic>?> _innertubePlayer(
  Dio dio,
  String html,
  String videoId,
) async {
  final key =
      RegExp(r'"INNERTUBE_API_KEY":"([^"]+)"').firstMatch(html)?.group(1);
  if (key == null) return null;
  final clientVersion =
      RegExp(r'"INNERTUBE_CLIENT_VERSION":"([^"]+)"').firstMatch(html)?.group(1) ??
          '2.20240101.00.00';
  try {
    final response = await dio.post<Map<String, dynamic>>(
      'https://www.youtube.com/youtubei/v1/player?key=$key',
      data: {
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': clientVersion,
            'hl': 'en',
          },
        },
        'videoId': videoId,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return response.data;
  } catch (e) {
    AnxLog.warning('YouTube: innertube player failed: $e');
    return null;
  }
}

/// Downloads the caption track as json3, falling back to the plain XML response.
Future<List<String>> _downloadCaptions(Dio dio, String baseUrl) async {
  final plain = baseUrl.replaceAll(RegExp(r'&fmt=[^&]*'), '');
  for (final url in <String>['$plain&fmt=json3', plain]) {
    try {
      final response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
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
