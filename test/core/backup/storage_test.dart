import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/backup/codec.dart';
import 'package:onexray/core/backup/storage.dart';
import 'package:onexray/core/tools/atomic_file.dart';
import 'package:saf_stream/saf_stream_platform_interface.dart';

class PullStorage extends SafStreamPlatform {
  final List<Uint8List> chunks;
  bool closed = false;
  Object? failure;
  PullStorage(this.chunks);
  @override
  Future<String> startReadCustomFileStream(
    String uri, {
    int? bufferSize,
  }) async {
    expect(uri, 'content://fixture/backup');
    expect(bufferSize, 64 * 1024);
    return 'fixture';
  }

  @override
  Future<Uint8List?> readCustomFileStreamChunk(String session) async {
    if (failure != null) throw failure!;
    return chunks.isEmpty ? null : chunks.removeAt(0);
  }

  @override
  Future<void> endReadCustomFileStream(String session) async {
    closed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('icloud_storage_plus');
  final originalSaf = SafStreamPlatform.instance;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    SafStreamPlatform.instance = originalSaf;
  });

  test(
    'Apple binding is local; only explicit reads and writes access iCloud',
    () async {
      final storage = PlatformBackupStorage(platform: TargetPlatform.iOS);
      final calls = <String>[];
      Uint8List? saved;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map;
        expect(args['containerId'], backupContainerId);
        expect(args['relativePath'], backupCloudPath);
        switch (call.method) {
          case 'getItemMetadata':
            return null;
          case 'readInPlaceBytes':
            return saved;
          case 'writeInPlaceBytes':
            saved = args['contents'] as Uint8List;
            return null;
          default:
            fail('Unexpected cloud operation');
        }
      });
      final target = (await storage.select(create: false))!;
      expect(calls, isEmpty);
      await storage.write(target, Uint8List.fromList([1, 2]));
      await storage.write(target, Uint8List.fromList([3]));
      expect(await storage.read(target), [3]);
      expect(calls, [
        'writeInPlaceBytes',
        'writeInPlaceBytes',
        'getItemMetadata',
        'readInPlaceBytes',
      ]);
    },
  );

  test(
    'Apple metadata rejects oversized files before requesting contents',
    () async {
      final storage = PlatformBackupStorage(platform: TargetPlatform.macOS);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getItemMetadata');
        return {
          'relativePath': backupCloudPath,
          'sizeInBytes': backupByteLimit + 1,
        };
      });
      await expectLater(
        storage.read((await storage.select(create: false))!),
        throwsFormatException,
      );
    },
  );

  test('SAF pull reads continue after short chunks and close at EOF', () async {
    final fake = PullStorage([
      Uint8List.fromList([1]),
      Uint8List.fromList([2, 3]),
    ]);
    SafStreamPlatform.instance = fake;
    expect(await readSafBackup('content://fixture/backup'), [1, 2, 3]);
    expect(fake.closed, isTrue);
  });

  test('SAF pull closes after size rejection or provider failure', () async {
    for (final failure in [null, const FileSystemException('access revoked')]) {
      final fake = PullStorage([Uint8List(backupByteLimit + 1)])
        ..failure = failure;
      SafStreamPlatform.instance = fake;
      await expectLater(
        readSafBackup('content://fixture/backup'),
        throwsA(isA<Exception>()),
      );
      expect(fake.closed, isTrue);
    }
  });

  test(
    'local replacement preserves unrelated files and rejects missing folders',
    () async {
      final root = await Directory('../references/cloud-backup/file-tests')
          .absolute
          .create(recursive: true);
      final dir = await root.createTemp('replacement-');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/$backupFileName');
      final unrelated = File('${target.path}.tmp');
      await unrelated.writeAsString('not ours');
      await writeBytesAtomically(target, [1, 2]);
      await writeBytesAtomically(target, [3]);
      expect(await target.readAsBytes(), [3]);
      expect(await unrelated.readAsString(), 'not ours');
      expect(await dir.list().length, 2);
      await expectLater(
        writeBytesAtomically(File('${dir.path}/missing/$backupFileName'), [4]),
        throwsA(isA<FileSystemException>()),
      );
      expect(await Directory('${dir.path}/missing').exists(), isFalse);
    },
  );
}
