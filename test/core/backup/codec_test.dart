import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/backup/codec.dart';
import 'package:onexray/core/backup/model.dart';

void main() {
  const smart = BackupSmartRouting(
    entryCount: 3,
    directRegions: ['CN'],
    directPrivate: true,
    directApple: true,
    directWindows: true,
    directDns: true,
    directDnsAddress: '8.8.8.8',
    fakeDns: false,
    blockAds: false,
  );
  BackupDocument sample() => BackupDocument(
    createdAt: 1000,
    coreConfigs: [
      for (var i = 0; i < 4; i++)
        BackupCoreConfig(
          '配置 $i',
          'raw',
          '',
          base64Encode(utf8.encode('{\n  "custom": 1\n}')),
        ),
    ],
    subscriptions: const [
      BackupSubscription(
        'Source',
        'https://example.com/sub',
        'private-fixture',
        'public-fixture',
        false,
        'stable-fixture',
      ),
    ],
    routingProfiles: const [],
    smartRouting: smart,
    geoData: const [
      BackupGeoData('custom', 'domain', 'https://example.com/custom.dat'),
    ],
  );

  test(
    'single JSON preserves original text, all Raw rows and sensitive fields',
    () {
      final document = sample();
      final result = decodeBackup(encodeBackup(document));
      expect(result.toJson(), document.toJson());
      expect(result.coreConfigs, hasLength(4));
      expect(result.subscriptions.single.hwid, 'stable-fixture');
      expect(result.subscriptions.single.hwidEnabled, false);
      expect(result.smartRouting.toJson(), isNot(contains('finalExitId')));
    },
  );

  test(
    'rejects missing partitions, unknown formats and forbidden metadata',
    () {
      for (final json in [
        sample().toJson()..remove('subscriptions'),
        sample().toJson()..remove('version'),
        sample().toJson()..['version'] = 4,
        sample().toJson()..['files'] = [],
        sample().toJson()
          ..['smartRouting'] = {...smart.toJson(), 'finalExitId': 7},
      ]) {
        expect(
          () => decodeBackup(Uint8List.fromList(utf8.encode(jsonEncode(json)))),
          throwsFormatException,
        );
      }
    },
  );

  test('diagnostics do not echo malformed credentials', () {
    expect(
      () => decodeBackup(Uint8List.fromList(utf8.encode('{"secret":"private'))),
      throwsA(
        isA<FormatException>().having(
          (e) => e.toString(),
          'safe message',
          isNot(contains('private')),
        ),
      ),
    );
    expect(
      () => decodeBackupConfiguration('invalid private'),
      throwsFormatException,
    );
    expect(
      () => decodeBackupConfiguration(base64Encode(utf8.encode('[]'))),
      throwsFormatException,
    );
  });

  test('bounds reads before decoding', () {
    expect(
      () => decodeBackup(Uint8List(backupByteLimit + 1)),
      throwsFormatException,
    );
    expect(() => decodeBackup(Uint8List(0)), throwsFormatException);
  });

  test('empty asset collections are a valid replacement backup', () {
    final document = BackupDocument(
      createdAt: 1000,
      coreConfigs: const [],
      subscriptions: const [],
      routingProfiles: const [],
      smartRouting: smart,
      geoData: const [],
    );
    expect(decodeBackup(encodeBackup(document)).toJson(), document.toJson());
  });

  test('invalid UTF-8 and field types are rejected without echoing values', () {
    expect(
      () => decodeBackup(Uint8List.fromList([0xff])),
      throwsFormatException,
    );
    for (final json in [
      sample().toJson()..['createdAt'] = 'not a timestamp',
      sample().toJson()..['coreConfigs'] = {},
      sample().toJson()
        ..['subscriptions'] = [
          {'name': 'private-fixture'},
        ],
      sample().toJson()..['createdAt'] = -1,
    ]) {
      expect(
        () => decodeBackup(Uint8List.fromList(utf8.encode(jsonEncode(json)))),
        throwsFormatException,
      );
    }
  });
}
