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

/// Tracks the launcher icons rendered by the per-app VPN lists: it asks
/// [AppIconService] for the icons of the packages the list actually shows, and
/// hands the rows the providers the service resolved.
///
/// The icons belong to the flow, not to this page: [AppIconService] creates one
/// provider per package and releases it when the flow owner leaves the per-app
/// VPN pages, so a page that is closed and reopened keeps painting from the
/// same decoded entry instead of leaving a second one behind.
class TunAppIconController extends PageCubit<AppIconViewState> {
  TunAppIconController() : this._(AppIconService());

  /// Overrides the shared icon cache so tests can stay off the bridge.
  @visibleForTesting
  TunAppIconController.withService(AppIconService service) : this._(service);

  /// Icons resolved earlier in the same flow are ready to paint on the first
  /// frame, which keeps the next page of the flow from opening on the fallback
  /// glyph.
  TunAppIconController._(AppIconService service)
    : _service = service,
      super(AppIconViewState(icons: service.resolvedIcons));

  final AppIconService _service;

  /// Packages already handed to the service, so a rebuilt row does not queue a
  /// second bridge call while the first one is still running.
  final _requested = <String>{};

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
    // paints an icon the service has already replaced.
    final icons = Map<String, ImageProvider?>.of(state.icons);
    icons[packageName] = _service.resolved(packageName);
    emit(state.copyWith(icons: icons));
  }
}
