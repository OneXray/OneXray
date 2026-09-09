import 'package:onexray/core/db/database/database.dart';

/// Runs before business services, keeping migration and background writes apart.
class StoragePreparation {
  static Future<bool>? _pending;

  /// Whether this process opened a missing database file as a new database.
  static Future<bool> ensureReady() => _pending ??= _prepare();

  static Future<bool> _prepare() async {
    try {
      final databaseFile = await AppDatabase.databaseFile;
      final databaseWasMissing = !await databaseFile.exists();
      await AppDatabase().customSelect('SELECT 1').get();
      return databaseWasMissing;
    } catch (_) {
      _pending = null;
      await AppDatabase.resetAfterOpenFailure();
      rethrow;
    }
  }
}
