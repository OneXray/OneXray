abstract final class LibXrayInvokeLimits {
  static const int maxJsonLength = 16 * 1024 * 1024;

  static void validate(String json, String kind) {
    if (json.length > maxJsonLength) {
      throw FormatException("libXray invoke $kind exceeds the size limit");
    }
  }
}
