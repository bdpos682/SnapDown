class HtmlUtils {
  static final RegExp _hexEntityRegex = RegExp(r'&#x([0-9a-fA-F]+);');
  static final RegExp _decEntityRegex = RegExp(r'&#([0-9]+);');

  /// Unescapes HTML entities commonly found in video titles (e.g. YouTube, TikTok, Facebook)
  /// e.g. "4,1&#xa0;tri&#x1ec7;u l&#x1b0;..." -> "4,1 triệu lư..."
  static String unescape(String? text) {
    if (text == null || text.isEmpty) return '';

    String result = text;

    // Decode hex entities: &#x1ec7;
    result = result.replaceAllMapped(_hexEntityRegex, (match) {
      try {
        final code = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(code);
      } catch (_) {
        return match.group(0)!;
      }
    });

    // Decode decimal entities: &#7879;
    result = result.replaceAllMapped(_decEntityRegex, (match) {
      try {
        final code = int.parse(match.group(1)!);
        return String.fromCharCode(code);
      } catch (_) {
        return match.group(0)!;
      }
    });

    // Named entities
    result = result
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\u00a0', ' '); // non-breaking space to regular space

    return result.trim();
  }
}
