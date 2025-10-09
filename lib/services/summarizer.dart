// A small local summarizer used as a placeholder for an AI summarization service.
//
// This file provides a `MockSummarizer` with a `summarize` method that accepts
// a description and optional location and returns a short summary string.
//
// TODO: Replace `MockSummarizer` with a real AI integration (e.g., call to an
// LLM endpoint) and handle network errors, rate limits, and caching.

class MockSummarizer {
  /// Produces a concise summary from the provided inputs.
  /// This intentionally keeps the logic simple and deterministic for now.
  Future<String> summarize({required String description, String? location}) async {
    // Simulate latency
    await Future.delayed(const Duration(milliseconds: 300));

    // Very naive extraction: take the first sentence and important keywords
    final desc = description.trim();
    final firstSentence = _firstSentence(desc);

    final peopleMentioned = _countPeopleWords(desc);
    final hazards = _extractHazards(desc);

    final buffer = StringBuffer();
    buffer.writeln(firstSentence.isNotEmpty ? firstSentence : 'No description provided.');
    if (location != null && location.isNotEmpty) buffer.writeln('Location: $location');
    if (peopleMentioned > 0) buffer.writeln('People involved (approx): $peopleMentioned');
    if (hazards.isNotEmpty) buffer.writeln('Hazards: ${hazards.join(', ')}');

    buffer.writeln('\nAI not yet implemented.');

    return buffer.toString().trim();
  }

  String _firstSentence(String text) {
    final idx = text.indexOf(RegExp(r'[.!?]'));
    if (idx == -1) return text;
    return text.substring(0, idx + 1);
  }

  int _countPeopleWords(String text) {
    // look for words that hint at numbers/people
    final lower = text.toLowerCase();
    final matches = RegExp(r'\b(\d+|one|two|three|four|five|six|seven|eight|nine|ten)\b').allMatches(lower);
    if (matches.isNotEmpty) return matches.length;
    // fallback: words like 'person', 'people', 'man', 'woman', 'child'
    final peopleWords = RegExp(r'\b(person|people|man|woman|child|children|bystander|victim)\b');
    return peopleWords.allMatches(lower).length;
  }

  List<String> _extractHazards(String text) {
    final lower = text.toLowerCase();
    final hazards = <String>[];
    final hazardKeywords = {
      'blood': 'bleeding',
      'fire': 'fire',
      'smoke': 'smoke',
      'gas': 'gas leak',
      'chemical': 'chemical hazard',
      'electr': 'electrical hazard',
      'stab': 'stab wound',
      'knife': 'knife',
      'gun': 'gun/weapon',
      'unconscious': 'unconscious person',
      'breath': 'breathing difficulty',
      'seiz': 'seizure',
      'fract': 'possible fracture',
      'injur': 'injury',
    };

    for (final entry in hazardKeywords.entries) {
      if (lower.contains(entry.key)) hazards.add(entry.value);
    }
    return hazards;
  }
}
