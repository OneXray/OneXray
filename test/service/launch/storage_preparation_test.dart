import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/launch/storage_preparation.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

class _IsolatedPaths extends PathProviderPlatform {
  _IsolatedPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'storage retries failed migration without VPN commands or snapshots',
    () async {
      final root = await Directory(
        '../references/onexray-refactor-validation/test-fixtures',
      ).absolute.create(recursive: true);
      final directory = await root.createTemp('startup-upgrade-');
      final oldPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _IsolatedPaths(directory.path);
      addTearDown(() async {
        await AppDatabase.resetAfterOpenFailure();
        PathProviderPlatform.instance = oldPaths;
        await directory.delete(recursive: true);
      });

      final file = File('${directory.path}/db.sqlite');
      final legacy = sqlite3.open(file.path);
      legacy.execute('''
        CREATE TABLE core_config (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          type TEXT NOT NULL, tags TEXT NOT NULL, data TEXT,
          delay INTEGER NOT NULL, sub_id INTEGER NOT NULL
        );
        CREATE TABLE subscription (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          url TEXT NOT NULL, timestamp INTEGER NOT NULL, count INTEGER NOT NULL,
          expanded INTEGER NOT NULL, age_secret_key TEXT, age_public_key TEXT
        );
        CREATE TABLE geo_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
          type TEXT NOT NULL, url TEXT NOT NULL, timestamp INTEGER NOT NULL,
          category_count INTEGER NOT NULL, rule_count INTEGER NOT NULL
        );
        INSERT INTO subscription (name, url, timestamp, count, expanded)
        VALUES ('Existing', 'https://example.com/sub', 123, 0, 0);
        CREATE INDEX connection_config ON core_config(name);
        PRAGMA user_version = 2;
      ''');
      legacy.close();

      const statusChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.onexray.BridgeHostApi.readVpnStatus',
        BridgeHostApi.pigeonChannelCodec,
      );
      const stopChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.onexray.BridgeHostApi.stopVpn',
        BridgeHostApi.pigeonChannelCodec,
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var reads = 0;
      var stops = 0;
      messenger.setMockDecodedMessageHandler(statusChannel, (_) async {
        reads++;
        return [NativeVpnCommandResult(state: NativeVpnCommandState.failed)];
      });
      messenger.setMockDecodedMessageHandler(stopChannel, (_) async {
        stops++;
        return [NativeVpnCommandResult(state: NativeVpnCommandState.failed)];
      });
      addTearDown(() {
        messenger.setMockDecodedMessageHandler(statusChannel, null);
        messenger.setMockDecodedMessageHandler(stopChannel, null);
      });

      final failed = StoragePreparation.ensureReady();
      expect(StoragePreparation.ensureReady(), same(failed));
      await expectLater(failed, throwsA(anything));

      final db = sqlite3.open(file.path);
      try {
        expect(db.userVersion, 2);
        expect(
          db.select('SELECT name FROM subscription').single['name'],
          'Existing',
        );
        expect(
          db.select('PRAGMA table_info(core_config)').map((row) => row['name']),
          isNot(contains('favorite')),
        );
        db.execute('DROP INDEX connection_config');
      } finally {
        db.close();
      }

      final retried = StoragePreparation.ensureReady();
      expect(retried, isNot(same(failed)));
      expect(await retried, isFalse);
      expect(StoragePreparation.ensureReady(), same(retried));
      expect(reads, 0);
      expect(stops, 0);
      expect(
        (await AppDatabase().subscriptionDao.allRows).single.name,
        'Existing',
      );
      expect(
        (await AppDatabase().customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        4,
      );
      expect(
        directory.listSync().where((entry) => entry.path.contains('.pre-v3-')),
        isEmpty,
      );
    },
    skip: !Platform.isMacOS,
  );
}
