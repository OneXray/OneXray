import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:icloud_storage_plus/icloud_storage.dart';
import 'package:onexray/core/backup/codec.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/atomic_file.dart';
import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';

const backupContainerId = 'iCloud.net.yuandev.onexray';
const backupCloudPath = 'Documents/$backupFileName';

class BackupTarget {
  final String identifier;
  final String label;
  const BackupTarget(this.identifier, this.label);
  factory BackupTarget.fromJson(Map<String, dynamic> json) =>
      BackupTarget(json['identifier'] as String, json['label'] as String);
  Map<String, dynamic> toJson() => {'identifier': identifier, 'label': label};
}

abstract interface class BackupStorage {
  Future<BackupTarget?> select({required bool create});
  Future<Uint8List> read(BackupTarget target);
  Future<void> write(BackupTarget target, Uint8List bytes);
  Future<void> release(BackupTarget target);
}

class PlatformBackupStorage implements BackupStorage {
  final _native = BackupHostApi();
  final TargetPlatform _platform;
  PlatformBackupStorage({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;
  bool get _apple =>
      _platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS;
  static bool get supported =>
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isAndroid ||
      Platform.isWindows;

  @override
  Future<BackupTarget?> select({required bool create}) async {
    if (_apple) {
      // Binding a fixed container is not consent to overwrite it.
      return const BackupTarget(
        backupContainerId,
        'iCloud Drive / $backupFileName',
      );
    }
    if (_platform == TargetPlatform.windows) {
      final directory = await FilePicker.getDirectoryPath();
      return directory == null
          ? null
          : BackupTarget(directory, p.join(directory, backupFileName));
    }
    if (_platform != TargetPlatform.android) {
      throw UnsupportedError('Backup storage is not supported');
    }
    final selected = await _native.selectBackupFile(create);
    return selected == null
        ? null
        : BackupTarget(selected.identifier, selected.label);
  }

  File _file(BackupTarget target) {
    if (!p.isAbsolute(target.identifier)) {
      throw const FormatException('Choose a backup directory again');
    }
    return File(p.join(target.identifier, backupFileName));
  }

  @override
  Future<Uint8List> read(BackupTarget target) async {
    if (_apple) {
      _requireContainer(target);
      // Manual read only. The plugin still allocates the complete file; this
      // precheck cannot eliminate size changes between metadata and reading.
      final metadata = await ICloudStorage.getItemMetadata(
        containerId: backupContainerId,
        relativePath: backupCloudPath,
      );
      if ((metadata?.sizeInBytes ?? 0) > backupByteLimit) {
        throw const FormatException('Backup exceeds 64 MiB');
      }
      final bytes = await ICloudStorage.readInPlaceBytes(
        containerId: backupContainerId,
        relativePath: backupCloudPath,
      );
      if (bytes.length > backupByteLimit) {
        throw const FormatException('Backup exceeds 64 MiB');
      }
      return bytes;
    }
    if (_platform == TargetPlatform.android) {
      await _native.requireBackupAccess(target.identifier);
      final token = RootIsolateToken.instance!;
      final identifier = target.identifier;
      return Isolate.run(() async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
        return readSafBackup(identifier);
      });
    }
    if (_platform == TargetPlatform.windows) {
      return readBackupStream(_file(target).openRead());
    }
    throw UnsupportedError('Backup storage is not supported');
  }

  @override
  Future<void> write(BackupTarget target, Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > backupByteLimit) {
      throw const FormatException('Invalid backup size');
    }
    if (_apple) {
      _requireContainer(target);
      await ICloudStorage.writeInPlaceBytes(
        containerId: backupContainerId,
        relativePath: backupCloudPath,
        contents: bytes,
      );
    } else if (_platform == TargetPlatform.windows) {
      // A moved/deleted OneDrive folder must be selected again, not recreated.
      await writeBytesAtomically(_file(target), bytes);
    } else if (_platform == TargetPlatform.android) {
      await _native.requireBackupAccess(target.identifier);
      await SafStream().writeFileUriBytes(
        target.identifier,
        bytes,
        append: false,
      );
    } else {
      throw UnsupportedError('Backup storage is not supported');
    }
  }

  @override
  Future<void> release(BackupTarget target) async {
    if (_platform == TargetPlatform.android) {
      await _native.releaseBackupFile(target.identifier);
    }
  }

  void _requireContainer(BackupTarget target) {
    if (target.identifier != backupContainerId) {
      throw const FormatException('Select the iCloud backup location again');
    }
  }
}

/// Pull one chunk at a time; the plugin's automatic stream pumps without
/// backpressure. JNI reads execute in the caller's worker isolate.
Future<Uint8List> readSafBackup(String identifier) async {
  final stream = SafStream();
  final session = await stream.startReadCustomFileStream(
    identifier,
    bufferSize: 64 * 1024,
  );
  try {
    final builder = BytesBuilder(copy: false);
    while (true) {
      final chunk = await stream.readCustomFileStreamChunk(session);
      if (chunk == null || chunk.isEmpty) break;
      if (builder.length + chunk.length > backupByteLimit) {
        throw const FormatException('Backup exceeds 64 MiB');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    await stream.endReadCustomFileStream(session);
  }
}

Future<Uint8List> readBackupStream(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (builder.length + chunk.length > backupByteLimit) {
      throw const FormatException('Backup exceeds 64 MiB');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}
