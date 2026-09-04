final class DownloadRequestHeaders {
  const DownloadRequestHeaders({this.agePublicKey});

  final String? agePublicKey;

  Map<String, String>? toHttpHeaders() {
    final publicKey = agePublicKey?.trim();
    if (publicKey == null || publicKey.isEmpty) {
      return null;
    }
    return <String, String>{'X-Age-Public-Key': publicKey};
  }
}
