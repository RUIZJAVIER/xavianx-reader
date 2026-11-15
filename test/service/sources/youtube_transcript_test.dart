import 'package:anx_reader/service/sources/youtube_transcript.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('youTubeVideoId', () {
    test('reads the id from the usual URL shapes', () {
      expect(youTubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
      expect(youTubeVideoId('https://youtu.be/dQw4w9WgXcQ?t=10'),
          'dQw4w9WgXcQ');
      expect(youTubeVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
      expect(youTubeVideoId('www.youtube.com/watch?v=dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
      expect(youTubeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('rejects other hosts and malformed ids', () {
      expect(youTubeVideoId('https://vimeo.com/123'), isNull);
      expect(youTubeVideoId('https://www.youtube.com/watch?v=short'), isNull);
      expect(youTubeVideoId(''), isNull);
    });
  });

  group('youTubeCaptionTrack', () {
    Map<String, dynamic> playerWith(List<Map<String, dynamic>> tracks) => {
          'captions': {
            'playerCaptionsTracklistRenderer': {'captionTracks': tracks},
          },
        };

    test('detects auto-generated (ASR) tracks', () {
      final player = playerWith([
        {'baseUrl': 'https://x/asr', 'languageCode': 'en', 'kind': 'asr'},
      ]);

      expect(youTubeCaptionTrack(player)?['baseUrl'], 'https://x/asr');
    });

    test('prefers manual tracks over auto-generated ones', () {
      final player = playerWith([
        {'baseUrl': 'https://x/asr', 'languageCode': 'en', 'kind': 'asr'},
        {'baseUrl': 'https://x/manual', 'languageCode': 'es'},
      ]);

      expect(youTubeCaptionTrack(player)?['baseUrl'], 'https://x/manual');
    });

    test('returns null when the player has no caption tracks', () {
      expect(youTubeCaptionTrack(const {}), isNull);
    });
  });

  group('YouTubeTranscriptCleaner', () {
    test('drops timestamps, sound cues and repeated caption lines', () {
      const raw = '''
[00:00:05] [Música]
00:00:12 Hola a todos (risas).
00:00:12 Hola a todos (risas).
>> Hoy hablamos de Flutter.
0:01:02 ¡Suscríbete!
''';
      final clean = YouTubeTranscriptCleaner.clean(raw);

      expect(clean, isNot(contains('[')));
      expect(clean, isNot(contains('risas')));
      expect(clean, isNot(contains('00:00')));
      expect(clean, isNot(contains('>>')));
      expect('Hola a todos'.allMatches(clean).length, 1);
      expect(clean, contains('Flutter'));
      expect(clean, contains('¡Suscríbete!'));
    });

    test('keeps parentheses that are part of the speech', () {
      final clean = YouTubeTranscriptCleaner.clean('Esto (en serio) importa.');
      expect(clean, contains('(en serio)'));
    });

    test('splits long transcripts into paragraphs', () {
      final raw = List.generate(
        60,
        (index) => 'Frase número $index sobre el tema.',
      ).join('\n');
      final clean = YouTubeTranscriptCleaner.clean(raw);

      expect(clean.split('\n').length, greaterThan(1));
      expect(clean, isNot(contains('\n\n')));
    });
  });
}
