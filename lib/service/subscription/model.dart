final class SubscriptionImportEntry {
  const SubscriptionImportEntry({required this.url, required this.name});

  final String url;
  final String name;
}

enum SubscriptionUpdateResult {
  success,
  notFound,
  downloadFailed,
  invalidContent,
  writeFailed,
}

abstract final class SubscriptionUrl {
  static String normalize(String value) {
    final normalized = value.replaceAll(RegExp(r"\s+"), "");
    final fragmentIndex = normalized.indexOf("#");
    return fragmentIndex < 0
        ? normalized
        : normalized.substring(0, fragmentIndex);
  }
}
