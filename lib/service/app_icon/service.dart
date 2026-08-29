import 'package:flutter/foundation.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';

typedef AppIconLoader = Future<Uint8List?> Function(String packageName);

/// Loads Android launcher icons for the per-app VPN lists on demand.
///
/// Icons are fetched one package at a time so opening the app lists stays as
/// fast as it is today, and resolved bytes are cached in memory so scrolling
/// back to an already visible row never re-crosses the platform bridge.
class AppIconService {
  static final AppIconService _singleton = AppIconService._internal();

  factory AppIconService() => _singleton;

  AppIconService._internal() : _loader = AppHostApi().getAppIcon;

  @visibleForTesting
  AppIconService.withLoader(AppIconLoader loader) : _loader = loader;

  final AppIconLoader _loader;

  /// Resolved icons. A present key with a `null` value means the platform has
  /// no icon for that package, so it is never requested again.
  final _icons = <String, Uint8List?>{};
  final _pending = <String, Future<Uint8List?>>{};

  bool isResolved(String packageName) => _icons.containsKey(packageName);

  Uint8List? resolved(String packageName) => _icons[packageName];

  Future<Uint8List?> load(String packageName) {
    if (_icons.containsKey(packageName)) {
      return Future.value(_icons[packageName]);
    }
    final pending = _pending[packageName];
    if (pending != null) {
      return pending;
    }
    final request = _load(packageName);
    _pending[packageName] = request;
    return request;
  }

  Future<Uint8List?> _load(String packageName) async {
    try {
      final icon = await _loader(packageName);
      final resolved = icon != null && icon.isNotEmpty ? icon : null;
      _icons[packageName] = resolved;
      return resolved;
    } catch (error, stackTrace) {
      // Leave the package unresolved so a later rebuild can retry it.
      ygLogger(
        'AppIconService.load failed for $packageName: '
        '$error\n$stackTrace',
      );
      return null;
    } finally {
      _pending.remove(packageName);
    }
  }

  void clear() {
    _icons.clear();
    _pending.clear();
  }
}
