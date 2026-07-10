import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/share/backup_archive.dart';
import 'package:path/path.dart' as p;

void main() {
  const rootFiles = {
    'manifest.json',
    'core_configs.json',
    'subscriptions.json',
    'geo_data.json',
  };

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onexray-backup-test-');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('extracts the supported flat backup structure', () async {
    final source = await _makeBackupSource(tempDir, rootFiles);
    final archivePath = p.join(tempDir.path, 'backup.zip');
    await _zipDirectory(source, archivePath);
    final output = p.join(tempDir.path, 'output');

    await const BackupArchiveExtractor(
      rootFiles: rootFiles,
      dataDirectory: 'dat',
    ).extract(archivePath, output);

    expect(await File(p.join(output, 'manifest.json')).exists(), isTrue);
    expect(await File(p.join(output, 'dat', 'geoip.dat')).exists(), isTrue);
  });

  test('preserves an empty data directory', () async {
    final source = await _makeBackupSource(
      tempDir,
      rootFiles,
      includeGeoData: false,
    );
    final archivePath = p.join(tempDir.path, 'empty-data.zip');
    await _zipDirectory(source, archivePath);
    final output = p.join(tempDir.path, 'empty-data-output');

    await const BackupArchiveExtractor(
      rootFiles: rootFiles,
      dataDirectory: 'dat',
    ).extract(archivePath, output);

    expect(await Directory(p.join(output, 'dat')).exists(), isTrue);
  });

  test('rejects unexpected files', () async {
    final source = await _makeBackupSource(tempDir, rootFiles);
    await File(p.join(source.path, 'secret.txt')).writeAsString('secret');
    final archivePath = p.join(tempDir.path, 'unexpected.zip');
    await _zipDirectory(source, archivePath);

    await expectLater(
      const BackupArchiveExtractor(
        rootFiles: rootFiles,
        dataDirectory: 'dat',
      ).extract(archivePath, p.join(tempDir.path, 'unexpected-output')),
      throwsA(isA<BackupArchiveException>()),
    );
  });

  test('rejects traversal paths', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('../outside.json', '{}'));
    final archivePath = p.join(tempDir.path, 'traversal.zip');
    await File(archivePath).writeAsBytes(ZipEncoder().encodeBytes(archive));

    await expectLater(
      const BackupArchiveExtractor(
        rootFiles: rootFiles,
        dataDirectory: 'dat',
      ).extract(archivePath, p.join(tempDir.path, 'traversal-output')),
      throwsA(isA<BackupArchiveException>()),
    );
  });

  test('enforces entry count limits before extraction', () async {
    final source = await _makeBackupSource(tempDir, rootFiles);
    final archivePath = p.join(tempDir.path, 'limited.zip');
    await _zipDirectory(source, archivePath);

    await expectLater(
      const BackupArchiveExtractor(
        rootFiles: rootFiles,
        dataDirectory: 'dat',
        limits: BackupArchiveLimits(maxFileCount: 1),
      ).extract(archivePath, p.join(tempDir.path, 'limited-output')),
      throwsA(isA<BackupArchiveException>()),
    );
  });
}

Future<Directory> _makeBackupSource(
  Directory root,
  Set<String> rootFiles, {
  bool includeGeoData = true,
}) async {
  final source = await Directory(
    p.join(root.path, 'source-${DateTime.now().microsecondsSinceEpoch}'),
  ).create();
  for (final name in rootFiles) {
    await File(p.join(source.path, name)).writeAsString('{}');
  }
  final dat = await Directory(p.join(source.path, 'dat')).create();
  if (includeGeoData) {
    await File(p.join(dat.path, 'geoip.dat')).writeAsString('dat');
    await File(p.join(dat.path, 'geoip.json')).writeAsString('{}');
  }
  return source;
}

Future<void> _zipDirectory(Directory source, String destination) async {
  final encoder = ZipFileEncoder();
  await encoder.zipDirectory(source, filename: destination);
  await encoder.close();
}
