import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/app_icon/service.dart';

class AppIconViewState {
  /// Icon providers per package. A present key with a `null` value means the
  /// platform has no icon for that package, so the fallback glyph is final.
  final Map<String, ImageProvider?> icons;

  const AppIconViewState({this.icons = const {}});

  AppIconViewState copyWith({Map<String, ImageProvider?>? icons}) {
    return AppIconViewState(icons: icons ?? this.icons);
  }
}

/// Owns the launcher icons rendered by the per-app VPN lists: it asks
/// [AppIconService] for the bytes of the packages the list actually shows, and
/// keeps the image providers built from them until the page is closed.
class TunAppIconController extends PageCubit<AppIconViewState> {
  TunAppIconController() : this._(AppIconService());

  /// Overrides the shared icon cache so tests can stay off the bridge.
  @visibleForTesting
  TunAppIconController.withService(AppIconService service) : this._(service);

  TunAppIconController._(AppIconService service)
    : _service = service,
      super(AppIconViewState(icons: _seedFrom(service)));

  final AppIconService _service;

  /// Packages already handed to the service, so a rebuilt row does not queue a
  /// second bridge call while the first one is still running.
  final _requested = <String>{};

  /// Providers built by this page, which are the only ones it may evict. A
  /// seeded provider shares its cache entry with the page that decoded it, so
  /// releasing it is that page's job.
  final _created = <ImageProvider>[];

  /// Icons resolved earlier in the same flow are ready to paint on the first
  /// frame, which keeps the next page of the flow from opening on the fallback
  /// glyph.
  static Map<String, ImageProvider?> _seedFrom(AppIconService service) {
    final icons = <String, ImageProvider?>{};
    for (final entry in service.resolvedIcons.entries) {
      final bytes = entry.value;
      icons[entry.key] = bytes == null ? null : MemoryImage(bytes);
    }
    return icons;
  }

  @override
  Future<void> disposePageResources() async {
    // The bytes are dropped by the flow owner, but the frames Flutter decoded
    // from them live in the global image cache and have to be evicted here.
    // Rows are unmounted before this runs, so nothing is listening any more and
    // the decoded frames are released with their cache entry.
    for (final icon in _created) {
      await icon.evict();
    }
  }

  void requestIcon(String packageName) {
    if (state.icons.containsKey(packageName) || !_requested.add(packageName)) {
      return;
    }
    unawaited(_loadIcon(packageName));
  }

  Future<void> _loadIcon(String packageName) async {
    await _service.load(packageName);
    if (!isPageActive) {
      return;
    }
    if (!_service.isResolved(packageName)) {
      // The bridge call failed, or the flow released its icons while this one
      // was in flight. Stay unresolved so a later rebuild can retry.
      _requested.remove(packageName);
      return;
    }
    // Read the cache instead of the reply, so a request that lost a race never
    // paints bytes the service has already replaced.
    final bytes = _service.resolved(packageName);
    final icon = bytes == null ? null : MemoryImage(bytes);
    if (icon != null) {
      _created.add(icon);
    }
    final icons = Map<String, ImageProvider?>.of(state.icons);
    icons[packageName] = icon;
    emit(state.copyWith(icons: icons));
  }
}
