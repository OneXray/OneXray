import 'dart:io';

import 'package:onexray/core/network/client.dart';
import 'package:onexray/service/geo_data/model.dart';

/// Keep untrusted source URLs out of diagnostics; every redirect stays HTTPS.
/// The per-file ceiling matches the existing backup archive limit.
Future<void> downloadGeoData(String url, File destination) async {
  try {
    await _downloadGeoData(url, destination);
  } catch (_) {
    // HttpException may include the complete source URL, including its token.
    throw const FormatException('Geodata download failed');
  }
}

Future<void> _downloadGeoData(String url, File destination) async {
  var uri = GeoDataInput.httpsUri(url);
  await NetClient().asyncInit();
  for (var redirects = 0; redirects <= 5; redirects++) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        NetClient().downloadUserAgent,
      );
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const FormatException('Invalid Geodata redirect');
        }
        uri = GeoDataInput.httpsUri(uri.resolve(location).toString());
        continue;
      }
      const limit = 512 * 1024 * 1024;
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > limit) {
        throw const FormatException('Geodata download failed');
      }
      var received = 0;
      final sink = destination.openWrite();
      try {
        await sink.addStream(
          response
              .map((chunk) {
                received += chunk.length;
                if (received > limit) {
                  throw const FormatException('Geodata file is too large');
                }
                return chunk;
              })
              .timeout(const Duration(seconds: 60)),
        );
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received == 0) throw const FormatException('Geodata file is empty');
      return;
    } finally {
      client.close(force: true);
    }
  }
  throw const FormatException('Too many Geodata redirects');
}
