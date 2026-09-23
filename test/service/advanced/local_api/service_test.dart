import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/advanced/local_api/service.dart';
import 'package:onexray/service/advanced/local_api/settings.dart';

void main() {
  Map<String, dynamic>? stored;
  var failWrite = false;
  late LocalApiService service;
  late HttpClient client;

  LocalApiService create({
    bool desktop = true,
    Future<Map<String, dynamic>?> Function()? readSettings,
  }) => LocalApiService.forTesting(
    readSettings: readSettings ?? () async => stored,
    writeSettings: (value) async {
      if (failWrite) throw StateError('Storage unavailable');
      stored = value;
    },
    info: () async => {'apiVersion': 1, 'appVersion': 'test'},
    validate: (_) async => {'status': 'passed'},
    compile: (_) async => {'status': 'passed'},
    desktop: desktop,
  );

  setUp(() {
    stored = null;
    failWrite = false;
    service = create();
    client = HttpClient()..findProxy = (_) => 'DIRECT';
    addTearDown(() async {
      client.close(force: true);
      await service.stop();
    });
  });

  Future<int> freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<int> status(LocalApiSettings settings, {String? token}) async {
    final request = await client.getUrl(
      Uri.parse('${settings.endpoint}/api/v1/info'),
    );
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${token ?? settings.token}',
    );
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  test(
    'off by default; enabling generates one persistent 256-bit token',
    () async {
      await service.start();
      expect(service.listening, isFalse);
      expect((await service.load()).token, isEmpty);
      final settings = await service.configure(
        enabled: true,
        port: await freePort(),
      );
      expect(base64Url.decode(base64Url.normalize(settings.token)).length, 32);
      expect(await status(settings), 200);
      await service.stop();
      service = create();
      await service.start();
      expect((await service.load()).token, settings.token);
      expect(await status(settings), 200);
      await service.configure(enabled: false, port: settings.port);
      expect(service.listening, isFalse);
      expect((await service.load()).token, settings.token);
    },
  );

  test(
    'explicit reset revokes old credentials without changing the port',
    () async {
      final before = await service.configure(
        enabled: true,
        port: await freePort(),
      );
      final after = await service.resetToken();
      expect(after.token, isNot(before.token));
      expect(after.port, before.port);
      expect(await status(after, token: before.token), 401);
      expect(await status(after), 200);
    },
  );

  test(
    'failed port change keeps the old listener and saved settings',
    () async {
      final before = await service.configure(
        enabled: true,
        port: await freePort(),
      );
      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(occupied.close);
      await expectLater(
        service.configure(enabled: true, port: occupied.port),
        throwsA(isA<SocketException>()),
      );
      expect((await service.load()).port, before.port);
      expect(stored, before.toJson());
      expect(await status(before), 200);
    },
  );

  test('startup preserves the socket failure and recovers on retry', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final settings = LocalApiSettings(
      enabled: true,
      port: occupied.port,
      token: base64Url.encode(List.filled(32, 1)).replaceAll('=', ''),
    );
    stored = settings.toJson();
    late SocketException conflict;
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        occupied.port,
      );
      await socket.close();
      fail('Expected the fixture port to be occupied');
    } on SocketException catch (error) {
      conflict = error;
    }

    await service.start();
    expect(service.listening, isFalse);
    expect(service.lastError, contains(conflict.message));
    expect(service.lastError, contains(conflict.osError!.message));
    expect(service.lastError, contains('${occupied.port}'));
    expect(service.lastError, isNot(contains(settings.token)));
    expect(stored, settings.toJson());

    await occupied.close();
    await service.start();
    expect(service.lastError, isNull);
    expect(service.listening, isTrue);
    expect(await status(settings), 200);
  });

  test(
    'startup reports malformed preferences without their JSON source',
    () async {
      const source = '{"token":"private-credential"';
      service = create(
        readSettings: () async => jsonDecode(source) as Map<String, dynamic>,
      );
      await service.start();
      expect(service.listening, isFalse);
      expect(service.lastError, contains('Unexpected end of input'));
      expect(service.lastError, isNot(contains('private-credential')));
      expect(service.lastError, isNot(contains(source)));
    },
  );

  test('startup retains preference access failures', () async {
    service = create(
      readSettings: () async => throw const FileSystemException(
        'Cannot read preferences',
        'preferences.json',
        OSError('Permission denied', 13),
      ),
    );
    await service.start();
    expect(service.listening, isFalse);
    expect(service.lastError, contains('Cannot read preferences'));
    expect(service.lastError, contains('Permission denied'));
  });

  test(
    'failed persistence discards candidate socket and keeps old credentials',
    () async {
      final before = await service.configure(
        enabled: true,
        port: await freePort(),
      );
      failWrite = true;
      final port = await freePort();
      await expectLater(
        service.configure(enabled: true, port: port),
        throwsStateError,
      );
      expect(await status(before), 200);
      final discarded = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await discarded.close();
      await expectLater(service.resetToken(), throwsStateError);
      expect((await service.load()).token, before.token);
    },
  );

  test(
    'data maintenance pauses requests; clearing revokes the cached token',
    () async {
      final settings = await service.configure(
        enabled: true,
        port: await freePort(),
      );
      await service.pauseForDataClear();
      expect(await status(settings), 503);
      await expectLater(
        service.configure(enabled: true, port: settings.port),
        throwsStateError,
      );
      service.resumeAfterDataClear();
      expect(await status(settings), 200);
      await service.pauseForDataClear();
      stored = null;
      await service.clearAfterDataClear();
      service.resumeAfterDataClear();
      expect(service.listening, isFalse);
      expect((await service.load()).token, isEmpty);
    },
  );

  test('mobile cannot enable a listener or create credentials', () async {
    service = create(desktop: false);
    await service.start();
    expect(service.listening, isFalse);
    await expectLater(
      service.configure(enabled: true, port: 18587),
      throwsStateError,
    );
    await expectLater(service.resetToken(), throwsStateError);
    expect(stored, isNull);
  });

  test('shutdown also closes a maintenance-paused listener', () async {
    await service.configure(enabled: true, port: await freePort());
    await service.pauseForDataClear();
    await service.stop();
    expect(service.listening, isFalse);
    service.resumeAfterDataClear();
    expect(service.listening, isFalse);
    await service.start();
    expect(service.listening, isTrue);
  });

  test('shutdown during preference write cannot reopen the listener', () async {
    final writing = Completer<void>();
    final release = Completer<void>();
    service = LocalApiService.forTesting(
      readSettings: () async => null,
      writeSettings: (value) async {
        writing.complete();
        await release.future;
        stored = value;
      },
      info: () async => {},
      validate: (_) async => {},
      compile: (_) async => {},
    );
    final configuring = service.configure(
      enabled: true,
      port: await freePort(),
    );
    await writing.future;
    final stopping = service.stop();
    release.complete();
    await configuring;
    await stopping;
    expect(service.listening, isFalse);
  });

  test(
    'corrupt persisted settings fail closed without echoing secrets',
    () async {
      stored = {'enabled': true, 'port': -1, 'token': 'secret'};
      await service.start();
      expect(service.listening, isFalse);
      expect(service.lastError, isNotNull);
      expect(service.lastError, isNot(contains('secret')));
    },
  );
}
