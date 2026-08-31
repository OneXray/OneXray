import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';

typedef AppIconLoader = Future<Uint8List?> Function(String packageName);

/// Loads Android launcher icons for the per-app VPN lists on demand.
///
/// Icons are fetched one package at a time so opening the app lists stays as
/// fast as it is today, and resolved icons are cached in memory so scrolling
/// back to an already visible row never re-crosses the platform bridge.
///
/// The cache owns the image providers, not just the bytes they wrap: a
/// [MemoryImage] keys Flutter's global image cache by the identity of its
/// bytes, so every provider built from one cached buffer would share a single
/// decoded entry. Keeping one provider per package here gives that entry a
/// single owner for the whole per-app VPN flow, which [clear] releases along
/// with the bytes.
///
/// The owner has to live here because nothing in the pages layer spans the
/// flow: the installed-app page is pushed as its own route, so the controller
/// of the page that opened it is not one of its ancestors and cannot hold the
/// icons both pages paint.
class AppIconService {
  static final AppIconService _singleton = AppIconService._internal();

  factory AppIconService() => _singleton;

  AppIconService._internal() : _loader = AppHostApi().getAppIcon;

  @visibleForTesting
  AppIconService.withLoader(AppIconLoader loader) : _loader = loader;

  final AppIconLoader _loader;

  /// Resolved icons. A present key with a `null` value means the platform has
  /// no icon for that package, so it is never requested again.
  final _icons = <String, MemoryImage?>{};
  final _pending = <String, _IconRequest>{};

  /// Bumped by [clear] so requests started for the previous flow can no longer
  /// write into the cache once they complete.
  var _generation = 0;

  /// Snapshot of the resolved cache, so a caller can restore its own view of
  /// the icons without re-crossing the bridge.
  Map<String, ImageProvider?> get resolvedIcons => Map.unmodifiable(_icons);

  bool isResolved(String packageName) => _icons.containsKey(packageName);

  ImageProvider? resolved(String packageName) => _icons[packageName];

  /// Resolves the icon of [packageName], reusing the cached provider, or the
  /// in-flight request when there is one.
  ///
  /// A `null` reply is not the same as the platform having no icon: a request
  /// that [clear] outlived also answers `null` and leaves the package
  /// unresolved. Check [isResolved] before treating the fallback glyph as
  /// final.
  Future<ImageProvider?> load(String packageName) {
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
    MemoryImage? icon;
    try {
      final bytes = await _loader(packageName);
      // A provider only ever exists inside the cache, so a request that
      // started before [clear] builds nothing at all: it cannot leave a
      // decoded entry behind for a flow that no longer owns it.
      if (request.generation == _generation) {
        icon = bytes != null && bytes.isNotEmpty ? MemoryImage(bytes) : null;
        _icons[packageName] = icon;
      }
    } catch (error, stackTrace) {
      // Leave the package unresolved so a later rebuild can retry it.
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
      request.completer.complete(icon);
    }
  }

  /// Releases the icons of the flow that is being left: the cached bytes and
  /// the frames Flutter decoded from them.
  ///
  /// This is the only place the icons are released, so it has to run after the
  /// last row painting them is gone: the page that owns the flow closes after
  /// the pages it pushed, and Flutter unmounts the rows before the providers
  /// around them. A row still painting an evicted provider would decode it
  /// again into an entry nobody owns.
  Future<void> clear() async {
    _generation += 1;
    final icons = List<MemoryImage?>.of(_icons.values);
    // The cache is emptied before the first await, so a page opened while the
    // eviction runs cannot restore a provider that is already being released.
    _icons.clear();
    _pending.clear();
    for (final icon in icons) {
      await icon?.evict();
    }
  }
}

/// One in-flight bridge call, tagged with the cache generation that started it.
class _IconRequest {
  _IconRequest(this.generation);

  final int generation;
  final completer = Completer<ImageProvider?>();
}
