import 'dart:async';

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
  final _pending = <String, _IconRequest>{};

  /// Bumped by [clear] so requests started for the previous flow can no longer
  /// write into the cache once they complete.
  var _generation = 0;

  /// Snapshot of the resolved cache, so a caller can restore its own view of
  /// the icons without re-crossing the bridge.
  Map<String, Uint8List?> get resolvedIcons => Map.unmodifiable(_icons);

  bool isResolved(String packageName) => _icons.containsKey(packageName);

  Uint8List? resolved(String packageName) => _icons[packageName];

  Future<Uint8List?> load(String packageName) {
    if (_icons.containsKey(packageName)) {
      return Future.value(_icons[packageName]);
    }
    final pending = _pending[packageName];
    if (pending != null) {
      return pending.completer.future;
    }
    final request = _IconRequest(_generation);
    _pending[packageName] = request;
    unawaited(_load(packageName, request));
    return request.completer.future;
  }

  Future<void> _load(String packageName, _IconRequest request) async {
    Uint8List? bytes;
    try {
      final icon = await _loader(packageName);
      bytes = icon != null && icon.isNotEmpty ? icon : null;
      if (request.generation == _generation) {
        _icons[packageName] = bytes;
      }
    } catch (error, stackTrace) {
      // Leave the package unresolved so a later rebuild can retry it.
      bytes = null;
      ygLogger(
        'AppIconService.load failed for $packageName: '
        '$error\n$stackTrace',
      );
    } finally {
      // A request started before [clear] must not drop the pending entry of
      // the request that replaced it.
      if (identical(_pending[packageName], request)) {
        _pending.remove(packageName);
      }
      request.completer.complete(bytes);
    }
  }

  void clear() {
    _generation += 1;
    _icons.clear();
    _pending.clear();
  }
}

/// One in-flight bridge call, tagged with the cache generation that started it.
class _IconRequest {
  _IconRequest(this.generation);

  final int generation;
  final completer = Completer<Uint8List?>();
}
