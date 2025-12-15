/// Service for detecting English sentences
class LanguageDetector {
  /// Common English words for basic detection
  static const List<String> _commonEnglishWords = [
    'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i',
    'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at',
    'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she',
    'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their',
  ];

  /// Detect if text contains English sentences
  bool isEnglish(String text) {
    if (text.trim().isEmpty) return false;
    
    // Check if text contains English sentence patterns
    final lowerText = text.toLowerCase();
    final words = lowerText.split(RegExp(r'\s+'));
    
    // Count English words
    int englishWordCount = 0;
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (_commonEnglishWords.contains(cleanWord)) {
        englishWordCount++;
      }
    }
    
    // If more than 20% of words are common English words, consider it English
    final threshold = words.length * 0.2;
    return englishWordCount >= threshold;
  }

  /// Extract sentences from text
  List<String> extractSentences(String text) {
    // Split by sentence endings (. ! ?)
    final sentences = text
        .split(RegExp(r'[.!?]+\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    
    return sentences;
  }

  /// Check if text is a valid sentence (has minimum length and structure)
  bool isValidSentence(String text, {int minLength = 10}) {
    if (text.length < minLength) return false;
    
    // Should start with capital letter or be all caps
    final firstChar = text[0];
    final startsWithCapital = firstChar.contains(RegExp(r'[A-Z]'));
    final isAllCaps = text.toUpperCase() == text;
    
    if (!startsWithCapital && !isAllCaps) {
      return false;
    }
    
    // Should contain at least one space (multiple words)
    if (!text.contains(' ')) return false;
    
    return true;
  }
}

