String normalizeTranscript(Iterable<String> parts) => parts
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String voiceTranscriptBody(String transcript) {
  final text = transcript.trim();
  return text.isEmpty ? '' : '## Transcript\n$text';
}
