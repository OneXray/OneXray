extension StringCleanExtensions on String {
  String get removeWhitespace => replaceAll(RegExp(r"\s+"), '');
}

extension ListStringCleanExtensions on List<String> {
  List<String> get removeWhitespace {
    final newList = <String>[];
    for (final text in this) {
      final cleanText = text.removeWhitespace;
      if (cleanText.isNotEmpty) {
        newList.add(cleanText);
      }
    }
    return newList;
  }
}

extension SetStringCleanExtensions on Set<String> {
  Set<String> get removeWhitespace {
    final newSet = <String>{};
    for (final text in this) {
      final cleanText = text.removeWhitespace;
      if (cleanText.isNotEmpty) {
        newSet.add(cleanText);
      }
    }
    return newSet;
  }
}
