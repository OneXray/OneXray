import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 1 subscriptions migrate with no age key pair', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'onexray-subscription-migration-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final databaseFile = File('${tempDir.path}/db.sqlite');
    final sqlite = sqlite3.open(databaseFile.path);
    sqlite
      ..execute('''
        CREATE TABLE subscription (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          count INTEGER NOT NULL,
          expanded INTEGER NOT NULL CHECK (expanded IN (0, 1))
        )
      ''')
      ..execute('''
        INSERT INTO subscription
          (name, url, timestamp, count, expanded)
        VALUES
          ('Existing', 'https://example.com/sub', 0, 1, 1)
      ''')
      ..execute('PRAGMA user_version = 1')
      ..close();

    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(database.close);

    final rows = await database.subscriptionDao.allRows;

    expect(database.schemaVersion, 3);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Existing');
    expect(rows.single.ageSecretKey, isNull);
    expect(rows.single.agePublicKey, isNull);
  });

  test('schema 2 subscriptions migrate with no age public key', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'onexray-subscription-migration-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final databaseFile = File('${tempDir.path}/db.sqlite');
    final sqlite = sqlite3.open(databaseFile.path);
    sqlite
      ..execute('''
        CREATE TABLE subscription (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          age_secret_key TEXT NULL,
          timestamp INTEGER NOT NULL,
          count INTEGER NOT NULL,
          expanded INTEGER NOT NULL CHECK (expanded IN (0, 1))
        )
      ''')
      ..execute('''
        INSERT INTO subscription
          (name, url, age_secret_key, timestamp, count, expanded)
        VALUES
          ('Encrypted', 'https://example.com/sub',
           'AGE-SECRET-KEY-1TEST', 0, 1, 1)
      ''')
      ..execute('PRAGMA user_version = 2')
      ..close();

    final database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(database.close);

    final rows = await database.subscriptionDao.allRows;

    expect(database.schemaVersion, 3);
    expect(rows, hasLength(1));
    expect(rows.single.ageSecretKey, 'AGE-SECRET-KEY-1TEST');
    expect(rows.single.agePublicKey, isNull);
  });
}
