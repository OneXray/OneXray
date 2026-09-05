import 'dart:async';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/upgrade_snapshot.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';

/// Runs before business services, keeping migration and background writes apart.
class StoragePreparation {
  static Future<bool>? _pending;

  /// Whether this process opened a missing database file as a new database.
  static Future<bool> ensureReady() => _pending ??= _prepare();

  static Future<bool> _prepare() async {
    try {
      final databaseFile = await AppDatabase.databaseFile;
      final databaseWasMissing = !await databaseFile.exists();
      await prepareUpgradeSnapshot(
        databaseFile,
        stopRunning: _stopBeforeUpgrade,
      );
      await AppDatabase().customSelect('SELECT 1').get();
      return databaseWasMissing;
    } catch (_) {
      _pending = null;
      await AppDatabase.resetAfterOpenFailure();
      rethrow;
    }
  }

  static Future<VpnStatus> _readStatus(
    Future<NativeVpnCommandResult> Function() command,
  ) async {
    final result = Completer<VpnStatus>();
    final listener = AppFlutterApi().vpnStatusController.stream.listen((
      status,
    ) {
      if (!result.isCompleted) {
        result.complete(status);
      }
    });
    try {
      final response = await command().timeout(const Duration(seconds: 15));
      if (response.state != NativeVpnCommandState.success) {
        throw StateError('Could not prepare VPN for database upgrade');
      }
      return await result.future.timeout(const Duration(seconds: 15));
    } finally {
      await listener.cancel();
    }
  }

  static Future<void> _stopBeforeUpgrade() async {
    if (await AppHostApi().cleanupStaleDesktopCore() == false) {
      throw StateError(
        'Could not stop the previous core before database upgrade',
      );
    }
    final status = await _readStatus(AppHostApi().readVpnStatus);
    if (status != VpnStatus.disconnected) {
      final stopped = await AppHostApi().stopVpn().timeout(
        const Duration(seconds: 15),
      );
      if (stopped.state != NativeVpnCommandState.success) {
        throw StateError('Could not stop VPN before database upgrade');
      }
      final elapsed = Stopwatch()..start();
      // Startup has not installed the normal Windows/desktop status watcher yet.
      while (await _readStatus(AppHostApi().readVpnStatus) !=
          VpnStatus.disconnected) {
        if (elapsed.elapsed > const Duration(seconds: 15)) {
          throw StateError('VPN did not stop before database upgrade');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }
}
