import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Called exclusively during startup, before Drift or maintenance opens the DB.
/// The SQLite backup includes committed WAL pages; copying db.sqlite alone does not.
Future<File?> prepareUpgradeSnapshot(
  File database, {
  required Future<void> Function() stopRunning,
}) async {
  if (!await database.exists()) return null;
  final source = sqlite3.open(database.path, mode: OpenMode.readOnly);
  try {
    final version = source.select('PRAGMA user_version').single.values.single;
    if (version == 3) return null;
    if (version == 0 &&
        source
            .select(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
            )
            .isEmpty) {
      return null; // A failed first creation may have left an empty file.
    }
    if (version != 1 && version != 2) {
      throw StateError('Unsupported database schema');
    }
    await stopRunning();
    final snapshot = File(
      '${database.path}.pre-v3-${DateTime.now().microsecondsSinceEpoch}',
    );
    final target = sqlite3.open(snapshot.path);
    try {
      await source.backup(target).drain<void>();
      final check = target.select('PRAGMA quick_check').single.values.single;
      if (check != 'ok') {
        throw StateError('Database snapshot validation failed');
      }
    } finally {
      target.close();
    }
    return snapshot;
  } finally {
    source.close();
  }
}
