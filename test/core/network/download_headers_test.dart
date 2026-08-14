import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/model.dart';
import 'package:package_info_plus/package_info_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  const publicKey = 'age1testpublickey';

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    PackageInfo.setMockInitialValues(
      appName: 'OneXray',
      packageName: 'net.yuandev.onexray',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test('uses the default OneXray UA for an unrelated download', () async {
    String? receivedAgeHeader;
    String? receivedUserAgent;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      receivedAgeHeader = request.headers.value('X-Age-Public-Key');
      receivedUserAgent = request.headers.value(HttpHeaders.userAgentHeader);
      request.response.write('plain subscription');
      await request.response.close();
    });

    final text = await NetClient().getText(_serverUrl(server));

    expect(text, 'plain subscription');
    expect(receivedAgeHeader, isNull);
    expect(
      receivedUserAgent,
      'OneXray/1.0.0 '
      '(net.yuandev.onexray; build:1; ${Platform.operatingSystem})',
    );
    expect(NetClient().downloadUserAgent, receivedUserAgent);
  });

  test('preserves the age header across a same-origin redirect', () async {
    final receivedHeaders = <String?>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      receivedHeaders.add(request.headers.value('X-Age-Public-Key'));
      if (request.uri.path == '/start') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/final');
      } else {
        request.response.write('encrypted subscription');
      }
      await request.response.close();
    });

    final text = await NetClient().getText(
      '${_serverUrl(server)}/start',
      requestHeaders: const DownloadRequestHeaders(agePublicKey: publicKey),
    );

    expect(text, 'encrypted subscription');
    expect(receivedHeaders, [publicKey, publicKey]);
  });

  test('preserves the age header across a cross-origin redirect', () async {
    String? sourceHeader;
    String? targetHeader;
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await source.close(force: true);
      await target.close(force: true);
    });
    target.listen((request) async {
      targetHeader = request.headers.value('X-Age-Public-Key');
      request.response.write('encrypted subscription');
      await request.response.close();
    });
    source.listen((request) async {
      sourceHeader = request.headers.value('X-Age-Public-Key');
      request.response.statusCode = HttpStatus.temporaryRedirect;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        '${_serverUrl(target)}/final',
      );
      await request.response.close();
    });

    final text = await NetClient().getText(
      '${_serverUrl(source)}/start',
      requestHeaders: const DownloadRequestHeaders(agePublicKey: publicKey),
    );

    expect(text, 'encrypted subscription');
    expect(sourceHeader, publicKey);
    expect(targetHeader, publicKey);
  });

  test('sends a Mihomo hybrid age public key without truncation', () async {
    final hybridPublicKey = 'age1pq1${List.filled(1950, 'q').join()}';
    String? receivedHeader;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      receivedHeader = request.headers.value('X-Age-Public-Key');
      request.response.write('encrypted subscription');
      await request.response.close();
    });

    final text = await NetClient().getText(
      _serverUrl(server),
      requestHeaders: DownloadRequestHeaders(agePublicKey: hybridPublicKey),
    );

    expect(text, 'encrypted subscription');
    expect(receivedHeader, hybridPublicKey);
  });
}

String _serverUrl(HttpServer server) =>
    'http://${server.address.address}:${server.port}';
