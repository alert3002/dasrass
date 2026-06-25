/// Простая клиентская фильтрация запрещённого контента при публикации.
class ContentFilter {
  ContentFilter._();

  static final _bannedPatterns = [
    RegExp(r'порно', caseSensitive: false),
    RegExp(r'наркот', caseSensitive: false),
    RegExp(r'оружи[ея]', caseSensitive: false),
    RegExp(r'мошенн', caseSensitive: false),
    RegExp(r'обман', caseSensitive: false),
    RegExp(r'казино', caseSensitive: false),
    RegExp(r'bitcoin\s*scam', caseSensitive: false),
    RegExp(r'виагр', caseSensitive: false),
  ];

  static String? validateListingText(String title, String description) {
    final text = '${title.trim()}\n${description.trim()}';
    if (text.trim().isEmpty) return null;
    for (final pattern in _bannedPatterns) {
      if (pattern.hasMatch(text)) {
        return 'Текст содержит запрещённые слова. Измените объявление или обратитесь в поддержку.';
      }
    }
    return null;
  }
}
