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
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'upgrade retries failed native checks and reads status without events',
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
      var replies = <NativeVpnCommandResult>[];
      var stopResult = NativeVpnCommandResult(
        state: NativeVpnCommandState.success,
      );
      var stops = 0;
      messenger.setMockDecodedMessageHandler(
        statusChannel,
        (_) async => [replies.removeAt(0)],
      );
      messenger.setMockDecodedMessageHandler(stopChannel, (_) async {
        stops++;
        return [stopResult];
      });
      addTearDown(() {
        messenger.setMockDecodedMessageHandler(statusChannel, null);
        messenger.setMockDecodedMessageHandler(stopChannel, null);
      });

      void expectUnchanged() {
        final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
        try {
          expect(db.userVersion, 2);
          expect(
            db.select('SELECT name FROM subscription').single['name'],
            'Existing',
          );
        } finally {
          db.close();
        }
        expect(
          directory.listSync().where(
            (entry) => entry.path.contains('.pre-v3-'),
          ),
          isEmpty,
        );
      }

      // Retry is part of startup: rejected status must not modify the old DB.
      for (final reply in [
        NativeVpnCommandResult(
          state: NativeVpnCommandState.failed,
          status: VpnStatus.disconnected,
        ),
        NativeVpnCommandResult(state: NativeVpnCommandState.success),
      ]) {
        replies = [reply];
        await expectLater(StoragePreparation.ensureReady(), throwsStateError);
        expect(stops, 0);
        expectUnchanged();
      }

      NativeVpnCommandResult status(VpnStatus value) => NativeVpnCommandResult(
        state: NativeVpnCommandState.success,
        status: value,
      );

      replies = [status(VpnStatus.connected)];
      stopResult = NativeVpnCommandResult(state: NativeVpnCommandState.failed);
      await expectLater(StoragePreparation.ensureReady(), throwsStateError);
      expect(stops, 1);
      expectUnchanged();

      // A successful stop alone is not proof of disconnection.
      replies = [
        status(VpnStatus.connected),
        NativeVpnCommandResult(state: NativeVpnCommandState.success),
      ];
      stopResult = NativeVpnCommandResult(state: NativeVpnCommandState.success);
      await expectLater(StoragePreparation.ensureReady(), throwsStateError);
      expect(stops, 2);
      expectUnchanged();

      replies = [
        status(VpnStatus.connected),
        status(VpnStatus.disconnecting),
        status(VpnStatus.disconnected),
      ];
      expect(await StoragePreparation.ensureReady(), isFalse);
      expect(stops, 3);
      expect(replies, isEmpty);
      expect(
        (await AppDatabase().subscriptionDao.allRows).single.name,
        'Existing',
      );
      expect(
        (await AppDatabase().customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        3,
      );
      final snapshot = directory.listSync().singleWhere(
        (entry) => entry.path.contains('.pre-v3-'),
      );
      final saved = sqlite3.open(snapshot.path, mode: OpenMode.readOnly);
      try {
        expect(saved.userVersion, 2);
        expect(
          saved.select('SELECT name FROM subscription').single['name'],
          'Existing',
        );
      } finally {
        saved.close();
      }
    },
    skip: !Platform.isMacOS,
  );
}
