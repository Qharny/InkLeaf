/// Tidies Whisper's raw output: drops markers such as `[BLANK_AUDIO]` or
/// `(music)` that stand for sounds rather than words, and the extra spaces
/// they leave behind. Returns '' when nothing was said.
String cleanTranscript(String raw) => raw
    .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)|\*[^*]*\*'), ' ')
    .split('\n')
    .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

/// [body] with [transcript] added: on its own if the body is empty,
/// otherwise after a blank line, so nothing already written is lost.
String appendTranscript(String body, String transcript) {
  final text = transcript.trim();
  if (text.isEmpty) return body;
  final existing = body.trimRight();
  return existing.isEmpty ? text : '$existing\n\n$text';
}
