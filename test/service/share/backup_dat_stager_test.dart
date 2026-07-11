import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/share/backup_dat_stager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late Directory backupDatDir;
  late Directory destination;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'onexray-backup-dat-stager-test-',
    );
    backupDatDir = await Directory(p.join(tempDir.path, 'backup-dat')).create();
    destination = await Directory(p.join(tempDir.path, 'staged-dat')).create();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('stages custom GeoData together with bundled assets', () async {
    await File(p.join(backupDatDir.path, 'custom.dat')).writeAsString('custom');
    await File(p.join(backupDatDir.path, 'custom.json')).writeAsString('{}');

    final stager = BackupDatStager(copySystemAssets: _writeSystemAssets);
    await stager.stage(
      backupDatDir: backupDatDir.path,
      destination: destination.path,
    );

    expect(
      await File(p.join(destination.path, 'custom.dat')).readAsString(),
      'custom',
    );
    expect(await File(p.join(destination.path, 'geoip.dat')).exists(), isTrue);
    expect(
      await File(p.join(destination.path, 'geosite.dat')).exists(),
      isTrue,
    );
    expect(
      await File(p.join(destination.path, 'timestamp.txt')).exists(),
      isTrue,
    );
  });

  test('stages bundled assets when backup GeoData is empty', () async {
    final stager = BackupDatStager(copySystemAssets: _writeSystemAssets);
    await stager.stage(
      backupDatDir: backupDatDir.path,
      destination: destination.path,
    );

    for (final name in [
      'geoip.dat',
      'geoip.json',
      'geosite.dat',
      'geosite.json',
      'timestamp.txt',
    ]) {
      expect(
        await File(p.join(destination.path, name)).exists(),
        isTrue,
        reason: '$name should be restored from bundled assets',
      );
    }
  });

  test('bundled assets replace conflicting backup files', () async {
    await File(p.join(backupDatDir.path, 'geoip.dat')).writeAsString('backup');

    final stager = BackupDatStager(
      copySystemAssets: (path) =>
          File(p.join(path, 'geoip.dat')).writeAsString('system'),
    );
    await stager.stage(
      backupDatDir: backupDatDir.path,
      destination: destination.path,
    );

    expect(
      await File(p.join(destination.path, 'geoip.dat')).readAsString(),
      'system',
    );
  });
}

Future<void> _writeSystemAssets(String path) async {
  for (final name in [
    'geoip.dat',
    'geoip.json',
    'geosite.dat',
    'geosite.json',
    'timestamp.txt',
  ]) {
    await File(p.join(path, name)).writeAsString('system');
  }
}
