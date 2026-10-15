import 'package:flutter_test/flutter_test.dart';
import 'package:my_note/features/record/domain/voice_transcript.dart';

void main() {
  test('normalizes transcript chunks into one line', () {
    final text = normalizeTranscript([
      '  hello  ',
      '',
      'world',
      '  from   inkleaf ',
    ]);
    expect(text, 'hello world from inkleaf');
  });

  test('builds transcript body only when text exists', () {
    expect(voiceTranscriptBody('   '), isEmpty);
    expect(
      voiceTranscriptBody('Hello there'),
      '## Transcript\nHello there',
    );
  });
}
