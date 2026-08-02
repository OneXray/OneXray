final class SubscriptionImportEntry {
  const SubscriptionImportEntry({required this.url, required this.name});

  final String url;
  final String name;
}

final class SubscriptionInput {
  const SubscriptionInput({
    required this.name,
    required this.url,
    this.ageSecretKey,
    this.agePublicKey,
  });

  final String name;
  final String url;
  final String? ageSecretKey;
  final String? agePublicKey;

  String? get normalizedAgeSecretKey {
    final value = ageSecretKey?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get normalizedAgePublicKey {
    final value = agePublicKey?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasIncompleteAgeKeyPair =>
      (normalizedAgeSecretKey == null) != (normalizedAgePublicKey == null);

  SubscriptionAgeContext? get normalizedAgeContext {
    final secretKey = normalizedAgeSecretKey;
    final publicKey = normalizedAgePublicKey;
    if (secretKey == null || publicKey == null) {
      return null;
    }
    return SubscriptionAgeContext(secretKey: secretKey, publicKey: publicKey);
  }
}

final class SubscriptionAgeContext {
  const SubscriptionAgeContext({
    required this.secretKey,
    required this.publicKey,
  });

  final String secretKey;
  final String publicKey;
}

final class SubscriptionInsertResult {
  const SubscriptionInsertResult({
    required this.status,
    this.subId = 0,
    this.count = 0,
  });

  final SubscriptionUpdateResult status;
  final int subId;
  final int count;

  bool get success => status == SubscriptionUpdateResult.success && count > 0;
}

enum SubscriptionUpdateResult {
  success,
  notFound,
  downloadFailed,
  invalidContent,
  invalidAgeSecretKey,
  missingAgeSecretKey,
  decryptFailed,
  contentTooLarge,
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
