import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/xray/runtime_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.onexray.BridgeHostApi.readLog',
    BridgeHostApi.pigeonChannelCodec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockDecodedMessageHandler(channel, null));

  test(
    'ordinary platform logs keep direct bounded file reads and full export',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'onexray-runtime-log',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/access.log');
      await file.writeAsString('first\nsecond\n');
      final tail = await RuntimeDiagnosticFiles.readLog(file.path, limit: 7);
      expect(tail!.offset, 6);
      expect(tail.size, 13);
      expect(String.fromCharCodes(tail.data), 'second\n');
      expect(
        String.fromCharCodes(
          await RuntimeDiagnosticFiles.readLogForExport(file.path),
        ),
        'first\nsecond\n',
      );
      expect(
        await RuntimeDiagnosticFiles.readLog('${directory.path}/missing.log'),
        isNull,
      );
      await Link('${directory.path}/link.log').create(file.path);
      await expectLater(
        RuntimeDiagnosticFiles.readLog('${directory.path}/link.log'),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  group('System Extension fixed log messages', () {
    test(
      'exports in at most 1 MiB blocks without using the user container path',
      () async {
        const size = RuntimeDiagnosticFiles.logChunkBytes + 17;
        var requests = 0;
        messenger.setMockDecodedMessageHandler(channel, (message) async {
          final arguments = message as List;
          expect(arguments[0], isFalse);
          final offset = arguments[1] as int;
          final limit = arguments[2] as int;
          expect(
            limit,
            lessThanOrEqualTo(RuntimeDiagnosticFiles.logChunkBytes),
          );
          requests++;
          return [
            NativeLogChunk(
              data: Uint8List(limit)..fillRange(0, limit, 97),
              offset: offset,
              size: size,
              fileId: '1:23',
            ),
          ];
        });
        final bytes = await RuntimeDiagnosticFiles.readLogForExport(
          '/not-a-readable-path/error.log',
          systemExtension: true,
          access: false,
        );
        expect(bytes.length, size);
        expect(bytes.first, 97);
        expect(bytes.last, 97);
        expect(requests, 2);
      },
    );

    test(
      'missing files and offline errors never fall back to another path',
      () async {
        messenger.setMockDecodedMessageHandler(channel, (_) async => [null]);
        expect(
          await RuntimeDiagnosticFiles.readLog(
            '/unused/access.log',
            systemExtension: true,
          ),
          isNull,
        );
        messenger.setMockDecodedMessageHandler(
          channel,
          (_) async => ['unavailable', 'Provider unavailable', null],
        );
        await expectLater(
          RuntimeDiagnosticFiles.readLog(
            '/unused/access.log',
            systemExtension: true,
          ),
          throwsA(isA<PlatformException>()),
        );
      },
    );

    test('rejects invalid bounds and malformed responses', () async {
      var requests = 0;
      messenger.setMockDecodedMessageHandler(channel, (_) async {
        requests++;
        return [
          NativeLogChunk(
            data: Uint8List(1),
            offset: 7,
            size: 8,
            fileId: '1:23',
          ),
        ];
      });
      await expectLater(
        AppHostApi().readLog(
          access: true,
          offset: 0,
          limit: RuntimeDiagnosticFiles.logChunkBytes + 1,
        ),
        throwsFormatException,
      );
      expect(requests, 0);
      await expectLater(
        AppHostApi().readLog(access: true, offset: 0, limit: 1),
        throwsFormatException,
      );
    });

    test(
      'rotation or the 64 MiB export ceiling fail without a partial export',
      () async {
        var requests = 0;
        messenger.setMockDecodedMessageHandler(channel, (message) async {
          final arguments = message as List;
          requests++;
          return [
            NativeLogChunk(
              data: Uint8List(arguments[2] as int),
              offset: arguments[1] as int,
              size: RuntimeDiagnosticFiles.logChunkBytes + 1,
              fileId: requests == 1 ? '1:23' : '1:24',
            ),
          ];
        });
        await expectLater(
          RuntimeDiagnosticFiles.readLogForExport(
            '/unused/access.log',
            systemExtension: true,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(requests, 2);
        messenger.setMockDecodedMessageHandler(
          channel,
          (_) async => [
            NativeLogChunk(
              data: Uint8List(0),
              offset: 0,
              size: RuntimeDiagnosticFiles.logExportBytes + 1,
              fileId: '1:23',
            ),
          ],
        );
        await expectLater(
          RuntimeDiagnosticFiles.readLogForExport(
            '/unused/access.log',
            systemExtension: true,
          ),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
  }, skip: !Platform.isMacOS);
}
