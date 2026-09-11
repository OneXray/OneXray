final class DownloadRequestHeaders {
  const DownloadRequestHeaders({this.agePublicKey, this.hwid});

  final String? agePublicKey;
  final String? hwid;

  Map<String, String>? toHttpHeaders() {
    final publicKey = agePublicKey?.trim();
    final headers = <String, String>{
      if (publicKey != null && publicKey.isNotEmpty)
        'X-Age-Public-Key': publicKey,
      'x-hwid': ?hwid,
    };
    return headers.isEmpty ? null : headers;
  }
}
