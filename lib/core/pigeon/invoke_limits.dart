abstract final class LibXrayInvokeLimits {
  static const int maxJsonSizeMiB = 16;
  static const int maxJsonBytes = maxJsonSizeMiB * 1024 * 1024;

  static void validate(String json, String kind) {
    if (_exceedsMaxJsonBytes(json)) {
      throw FormatException(
        "libXray invoke $kind exceeds the $maxJsonSizeMiB MiB size limit",
      );
    }
  }

  static bool _exceedsMaxJsonBytes(String json) {
    if (json.length > maxJsonBytes) {
      return true;
    }

    var byteLength = 0;
    for (final rune in json.runes) {
      if (rune <= 0x7F) {
        byteLength += 1;
      } else if (rune <= 0x7FF) {
        byteLength += 2;
      } else if (rune <= 0xFFFF) {
        byteLength += 3;
      } else {
        byteLength += 4;
      }
      if (byteLength > maxJsonBytes) {
        return true;
      }
    }
    return false;
  }
}
