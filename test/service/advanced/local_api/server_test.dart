import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/advanced/local_api/server.dart';

void main() {
  const credential = 'test-credential';
  late LocalApiServer server;
  late HttpClient client;
  late String token;
  late bool available;
  late List<Map<String, dynamic>> calls;
  late Uri endpoint;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? handler;

  setUp(() async {
    token = credential;
    available = true;
    calls = [];
    handler = null;
    server = LocalApiServer(
      token: () => token,
      available: () => available,
      info: () async => {'appVersion': 'test', 'coreVersion': 'test'},
      validate: (request) async {
        calls.add(request);
        return handler != null
            ? await handler!(request)
            : {
                'apiVersion': 1,
                'status': 'passed',
                'stage': 'kernel',
                'diagnostics': [],
              };
      },
      compile: (request) async {
        calls.add(request);
        return {
          'apiVersion': 1,
          'status': 'passed',
          'stage': 'compile',
          'compiledConfig': '{}',
        };
      },
    );
    server.attach(await LocalApiServer.bind(0));
    endpoint = Uri.parse('http://127.0.0.1:${server.port}');
    client = HttpClient()..findProxy = (_) => 'DIRECT';
    addTearDown(() async {
      client.close(force: true);
      await server.close();
    });
  });

  Future<({int status, Map<String, dynamic> body})> request(
    String path, {
    String method = 'GET',
    String? auth = credential,
    String? origin,
    String? host,
    Object? body,
    String? text,
    String contentType = 'application/json',
  }) async {
    final req = await client.openUrl(method, endpoint.resolve(path));
    if (auth != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $auth');
    }
    if (origin != null) req.headers.set('origin', origin);
    if (host != null) req.headers.set(HttpHeaders.hostHeader, host);
    if (body != null || text != null) {
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      req.add(utf8.encode(text ?? jsonEncode(body)));
    }
    final response = await req.close();
    expect(response.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
    expect(response.headers.value('access-control-allow-origin'), isNull);
    return (
      status: response.statusCode,
      body: jsonDecode(
        await utf8.decoder.bind(response).join(),
      ) as Map<String, dynamic>,
    );
  }

  const input = {'kind': 'raw', 'text': '{"name":"Example","outbounds":[]}'};

  test('info requires authentication and does not reveal the token', () async {
    expect((await request('/api/v1/info', auth: null)).status, 401);
    expect((await request('/api/v1/info', auth: 'wrong')).status, 401);
    final result = await request('/api/v1/info');
    expect(result.status, 200);
    expect(result.body['apiVersion'], 1);
    expect(jsonEncode(result.body), isNot(contains(credential)));
    expect(calls, isEmpty);
  });

  test(
    'rejects browser origins, rebinding host and query credentials',
    () async {
      for (final origin in [
        'null',
        'https://example.com',
        endpoint.toString(),
      ]) {
        expect((await request('/api/v1/info', origin: origin)).status, 403);
      }
      expect((await request('/api/v1/info', host: 'evil.example')).status, 400);
      expect((await request('/api/v1/info?token=$credential')).status, 400);
    },
  );

  test('only explicit methods and endpoints can dispatch', () async {
    expect((await request('/api/v1/info', method: 'POST')).status, 405);
    expect((await request('/api/v1/config/validate')).status, 405);
    expect(
      (await request(
        '/api/v1/invoke',
        method: 'POST',
        body: {'method': 'runXray'},
      )).status,
      404,
    );
    expect((await request('/api/v1/token')).status, 404);
    expect(calls, isEmpty);
  });

  test('passes original configuration text without reencoding it', () async {
    const text = '{\r\n "name": "例子",\r\n "outbounds": []\r\n}';
    final result = await request(
      '/api/v1/config/validate',
      method: 'POST',
      body: {'kind': 'raw', 'text': text},
    );
    expect(result.status, 200);
    expect(result.body['status'], 'passed');
    expect(calls.single['text'], text);
    final compiled = await request(
      '/api/v1/config/compile',
      method: 'POST',
      body: input,
    );
    expect(compiled.body['stage'], 'compile');
  });

  test('invalid envelopes cannot reach configuration handlers', () async {
    expect(
      (await request(
        '/api/v1/config/validate',
        method: 'POST',
        text: '{',
      )).status,
      400,
    );
    for (final value in <Object>[
      [],
      {},
      {'kind': 'runXray', 'text': '{}'},
      {'kind': 'raw', 'text': {}},
      {'kind': 'raw', 'text': '{}', 'name': 2},
    ]) {
      expect(
        (await request(
          '/api/v1/config/validate',
          method: 'POST',
          body: value,
        )).status,
        400,
      );
    }
    expect(
      (await request(
        '/api/v1/config/validate',
        method: 'POST',
        body: input,
        contentType: 'text/plain',
      )).status,
      415,
    );
    expect(calls, isEmpty);
  });

  test('oversized requests are rejected before invoking the backend', () async {
    final result = await request(
      '/api/v1/config/validate',
      method: 'POST',
      text: ' ' * (LocalApiServer.maximumBodyBytes + 1),
    );
    expect(result.status, 413);
    expect(calls, isEmpty);
  });

  test(
    'one request remains active across client and listener changes',
    () async {
      final entered = Completer<void>();
      final release = Completer<Map<String, dynamic>>();
      handler = (_) {
        entered.complete();
        return release.future;
      };
      final first = request(
        '/api/v1/config/validate',
        method: 'POST',
        body: input,
      );
      await entered.future;
      expect(
        (await request(
          '/api/v1/config/compile',
          method: 'POST',
          body: input,
        )).status,
        409,
      );
      expect((await request('/api/v1/info')).status, 200);
      available = false;
      expect(
        (await request(
          '/api/v1/config/validate',
          method: 'POST',
          body: input,
        )).status,
        503,
      );
      var drained = false;
      final drain = server.drained.then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      release.complete({'status': 'passed', 'stage': 'kernel'});
      expect((await first).status, 200);
      await drain;
      expect(drained, isTrue);
    },
  );

  test('reset immediately rejects old credentials', () async {
    token = 'replacement';
    expect((await request('/api/v1/info')).status, 401);
    expect((await request('/api/v1/info', auth: token)).status, 200);
  });

  test(
    'kernel rejection remains a result, unexpected exceptions are not leaked',
    () async {
      handler = (_) async => {
        'status': 'failed',
        'stage': 'kernel',
        'diagnostics': [
          {'code': 'kernelRejected', 'message': 'Unknown protocol'},
        ],
      };
      expect(
        (await request(
          '/api/v1/config/validate',
          method: 'POST',
          body: input,
        )).body['status'],
        'failed',
      );
      handler = (_) async =>
          throw StateError('Secret $credential in diagnostic');
      final result = await request(
        '/api/v1/config/validate',
        method: 'POST',
        body: input,
      );
      expect(result.status, 500);
      expect(result.body['status'], 'notRun');
      expect(jsonEncode(result.body), isNot(contains(credential)));
    },
  );
}
