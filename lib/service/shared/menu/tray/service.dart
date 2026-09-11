import 'dart:ui';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/ffi/windows/mode.dart';
import 'package:onexray/service/settings/language/service.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/failure.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/servers/subscription/failure.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/failure.dart' show appFailureMessage;
import 'package:onexray/service/shared/menu/tray/menu.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/launch/app_startup.dart';
import 'package:onexray/service/shared/notification/service.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:collection/collection.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:window_manager/window_manager.dart';

final class TrayService with TrayListener {
  static final TrayService _singleton = TrayService._internal();

  factory TrayService() => _singleton;

  TrayService._internal()
    : _databaseOverride = null,
      _coordinatorOverride = null,
      _connect = (() => ConnectionCoordinator.instance.connect()),
      _notify = ((message) => NotificationService().pushNotification(message)),
      _showMainWindow = (() => AppStartupService().showMainWindow());

  @visibleForTesting
  TrayService.forTesting({
    required this._connect,
    required this._notify,
    required this._showMainWindow,
    AppDatabase? database,
    ConnectionCoordinator? coordinator,
  }) : _databaseOverride = database,
       _coordinatorOverride = coordinator;

  final AppDatabase? _databaseOverride;
  final ConnectionCoordinator? _coordinatorOverride;
  AppDatabase get _db => _databaseOverride ?? AppDatabase();
  ConnectionCoordinator get _coordinator =>
      _coordinatorOverride ?? ConnectionCoordinator.instance;

  Future<void> Function(
    Map<String, dynamic> values,
    String label,
    Future<void> Function() validate,
  )?
  onConfigurationChange;
  TrayMenuData _data = TrayMenuData();
  final _listeners = <StreamSubscription<dynamic>>[];
  final _pendingUpdates = <String>{};
  bool _changingConfiguration = false;
  bool _refreshRequested = false;
  bool _menuOpen = false;
  Future<void>? _refreshing;

  final Future<void> Function() _connect;
  final Future<void> Function(String) _notify;
  final Future<void> Function() _showMainWindow;

  //==========================
  var _initialized = false;
  ConnectionPhase? _lastPhase;
  bool? _lastCanDisconnect;

  bool get _canQuitWithoutStoppingVpn =>
      AppPlatform.isMacOS ||
      (AppPlatform.isWindows && windowsBuildMode == WindowsMode.msix);

  void init() {
    if (!AppPlatform.isDesktop || _initialized) {
      return;
    }

    trayManager.addListener(this);
    _coordinator.state.addListener(_connectionChanged);
    _initialized = true;
    _listeners.add(
      TrayMenuData.watch(_db).listen(
        (data) {
          _data = data;
          _requestRefresh();
        },
        onError: (Object error, StackTrace stackTrace) {
          ygLogger('Read tray choices failed: $error\n$stackTrace');
        },
      ),
    );
    _listeners.add(
      AppEventBus.instance.stream
          .map((state) => state.languageCode)
          .distinct()
          .listen((_) => _requestRefresh()),
    );
  }

  void dispose() {
    if (!AppPlatform.isDesktop || !_initialized) {
      return;
    }
    trayManager.removeListener(this);
    _coordinator.state.removeListener(_connectionChanged);
    for (final listener in _listeners) {
      unawaited(listener.cancel());
    }
    _listeners.clear();
    onConfigurationChange = null;
    _lastPhase = null;
    _lastCanDisconnect = null;
    _initialized = false;
  }

  void _connectionChanged() {
    final view = _coordinator.state.value;
    if (_lastPhase == view.phase && _lastCanDisconnect == view.canDisconnect) {
      return;
    }
    _lastPhase = view.phase;
    _lastCanDisconnect = view.canDisconnect;
    _requestRefresh();
  }

  void _requestRefresh() {
    if (!_initialized) return;
    unawaited(
      refreshTrayManager().catchError((Object error, StackTrace stackTrace) {
        ygLogger('Refresh tray failed: $error\n$stackTrace');
      }),
    );
  }

  Future<void> refreshTrayManager() {
    _refreshRequested = true;
    if (_menuOpen) return Future.value();
    return _refreshing ??= _refreshMenu().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _refreshMenu() async {
    if (!AppPlatform.isDesktop) {
      return;
    }
    do {
      _refreshRequested = false;
      await _publishMenu();
    } while (_refreshRequested && _initialized && !_menuOpen);
  }

  Future<void> _publishMenu() async {
    final view = _coordinator.state.value;
    final running = view.canDisconnect || view.busy;
    await _setTrayIcon(running);

    final items = <MenuItem>[];
    if (running) {
      items.add(
        MenuItem(
          key: _TrayMenuKey.stopVpn.name,
          label: appLocalizationsNoContext().menuBarStopVpn,
        ),
      );
    } else {
      items.add(
        MenuItem(
          key: _TrayMenuKey.startVpn.name,
          label: appLocalizationsNoContext().menuBarStartVpn,
          disabled: view.busy,
        ),
      );
    }
    items.add(
      MenuItem(
        key: _TrayMenuKey.reconnect.name,
        label: appLocalizationsNoContext().menuBarReconnect,
        disabled: view.phase != ConnectionPhase.connected || view.busy,
      ),
    );
    items.add(MenuItem.separator());
    items.addAll(
      _data.selectionItems(
        appLocalizationsNoContext(),
        busy: view.busy || _changingConfiguration,
      ),
    );
    items.add(MenuItem.separator());
    items.addAll(
      _data.updateItems(appLocalizationsNoContext(), _pendingUpdates),
    );
    items.add(MenuItem.separator());
    items.add(
      MenuItem(
        key: _TrayMenuKey.showApp.name,
        label: appLocalizationsNoContext().menuBarShowApp,
      ),
    );
    items.add(
      MenuItem(
        key: _TrayMenuKey.quitApp.name,
        label: appLocalizationsNoContext().menuBarQuitApp,
      ),
    );
    if (_canQuitWithoutStoppingVpn) {
      items.add(
        MenuItem(
          key: _TrayMenuKey.quitAndStopVpn.name,
          label: appLocalizationsNoContext().menuBarQuitAndStopVpn,
        ),
      );
    }

    final menu = Menu(items: items);
    await trayManager.setContextMenu(menu);
  }

  Future<void> _setTrayIcon(bool running) async {
    var icon = "";
    if (AppPlatform.isWindows) {
      if (running) {
        icon = Assets.icon.trayRunningIco;
      } else {
        icon = Assets.icon.trayNotRunningIco;
      }
    } else {
      if (running) {
        icon = Assets.icon.trayRunningPng.path;
      } else {
        icon = Assets.icon.trayNotRunningPng.path;
      }
    }
    await trayManager.setIcon(icon);
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_openMenu());
    super.onTrayIconMouseDown();
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_openMenu());
    super.onTrayIconRightMouseDown();
  }

  Future<void> _openMenu() async {
    if (!_initialized || _menuOpen) return;
    _menuOpen = true;
    try {
      // Keep the native popup and tray_manager's Dart ID lookup on the same
      // menu until AppKit/Win32 finishes tracking it. Coalesce stream updates.
      await _refreshing;
      if (!_initialized) return;
      await trayManager.popUpContextMenu();
    } catch (error, stackTrace) {
      ygLogger('Open tray menu failed: $error\n$stackTrace');
    } finally {
      _menuOpen = false;
      if (_refreshRequested) _requestRefresh();
    }
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == null || menuItem.disabled) {
      return;
    }
    final key = _TrayMenuKey.fromString(menuItem.key!);
    try {
      if (menuItem.key!.startsWith('update')) {
        await _update(menuItem.key!);
        return;
      }
      if (key == null) {
        await _select(menuItem.key!);
        return;
      }
      switch (key) {
        case _TrayMenuKey.startVpn:
          await _connect();
          break;
        case _TrayMenuKey.reconnect:
          await _coordinator.apply(
            await _coordinator.configuration,
            connect: true,
          );
          break;
        case _TrayMenuKey.stopVpn:
          await ConnectionCoordinator.instance.disconnect();
          break;
        case _TrayMenuKey.showApp:
          await windowManager.show();
          await windowManager.focus();
          break;
        case _TrayMenuKey.quitApp:
          if (!_canQuitWithoutStoppingVpn) {
            await ConnectionCoordinator.instance.disconnect();
          }
          await ServicesBinding.instance.exitApplication(
            AppExitType.cancelable,
          );
          break;
        case _TrayMenuKey.quitAndStopVpn:
          await ConnectionCoordinator.instance.disconnect();
          await ServicesBinding.instance.exitApplication(
            AppExitType.cancelable,
          );
          break;
      }
    } catch (error) {
      if (failureCancelled(error) ||
          connectionFailureReason(error) == 'cancelled') {
        return;
      }
      if (key == _TrayMenuKey.startVpn || key == _TrayMenuKey.reconnect) {
        try {
          await _notify(
            connectionFailureMessage(appLocalizationsNoContext(), error: error),
          );
        } catch (notificationError) {
          ygLogger('Tray connection notification failed: $notificationError');
        }
        if (!connectionFailureNeedsWindow(error)) return;
      } else if (key == null) {
        await _notice(
          menuItem.key!.startsWith('update')
              ? appFailureMessage(appLocalizationsNoContext(), error)
              : connectionFailureMessage(
                  appLocalizationsNoContext(),
                  error: error,
                ),
        );
        return;
      }
      // Keep the coordinator's failure/permission state for the normal UI retry.
      await _showMainWindow();
    }
  }

  Future<void> _select(String key) async {
    final handler = onConfigurationChange;
    if (handler == null || _changingConfiguration) return;
    final l = appLocalizationsNoContext();
    final separator = key.indexOf(':');
    final kind = separator < 0 ? key : key.substring(0, separator);
    final value = separator < 0 ? '' : key.substring(separator + 1);
    final id = int.tryParse(value);
    Map<String, dynamic> values;
    String label;
    Future<void> validate() async {
      final exists = switch (kind) {
        'server' || 'raw' =>
          (await _db.coreConfigDao.searchRow(id!))?.type ==
              (kind == 'raw' ? 'raw' : 'outbound'),
        'source' =>
          id == 0
              ? (await _db.coreConfigDao.allOutboundRowsWithDataBySubId(0))
                    .isNotEmpty
              : await _db.subscriptionDao.searchRow(id!) != null,
        'custom' => await _db.routingProfileDao.searchRow(id!) != null,
        _ => true,
      };
      if (!exists) throw const AppFailure(FailureCategory.conflict, 'notFound');
    }

    switch (kind) {
      case 'automatic':
        values = {
          'expert': false,
          'selection': const ServerSelection.automatic().toJson(),
        };
        label = l.prototypeAutomaticSelection;
      case 'server':
      case 'source':
        if (id == null) return;
        await validate();
        values = {
          'expert': false,
          'selection':
              (kind == 'server'
                      ? ServerSelection.server(id)
                      : ServerSelection.source(id))
                  .toJson(),
        };
        label = kind == 'server'
            ? (await _db.coreConfigDao.searchRow(id))!.name
            : id == 0
            ? l.prototypeManualAdditions
            : (await _db.subscriptionDao.searchRow(id))!.name;
      case 'region':
        values = {
          'expert': false,
          'selection': ServerSelection.region(value).toJson(),
        };
        label = value.isEmpty ? '—' : l.countryRegionName(value);
      case 'raw':
        if (id == null) return;
        await validate();
        values = {'expert': true, 'rawId': id};
        label = (await _db.coreConfigDao.searchRow(id))!.name;
      case 'custom':
        if (id == null) return;
        await validate();
        values = {
          'expert': false,
          'trafficMode': TrafficMode.custom.name,
          'customId': id,
        };
        label = (await _db.routingProfileDao.searchRow(id))!.name;
      case 'traffic':
        if (value != TrafficMode.smart.name &&
            value != TrafficMode.allVpn.name) {
          return;
        }
        values = {'expert': false, 'trafficMode': value};
        label = value == TrafficMode.smart.name
            ? l.prototypeSmartRoutingRecommended
            : l.prototypeAllViaVpn;
      default:
        return;
    }
    _changingConfiguration = true;
    _requestRefresh();
    try {
      await handler(values, label, validate);
    } finally {
      _changingConfiguration = false;
      _requestRefresh();
    }
  }

  Future<void> _update(String key) async {
    if (!_pendingUpdates.add(key)) return;
    _requestRefresh();
    final l = appLocalizationsNoContext();
    try {
      if (key == 'updateSubscriptions') {
        await _notice(
          subscriptionRefreshMessage(
            l,
            await SubscriptionService().refreshAll(),
          ),
        );
      } else if (key.startsWith('updateSubscription:')) {
        final id = int.tryParse(key.substring('updateSubscription:'.length));
        final source = id == null
            ? null
            : await _db.subscriptionDao.searchRow(id);
        if (source == null) {
          throw const AppFailure(FailureCategory.conflict, 'notFound');
        }
        await _notice(
          subscriptionRefreshMessage(l, {
            source: await SubscriptionService().refreshSubscriptionResult(
              source,
            ),
          }),
        );
      } else if (key == 'updateGeodata') {
        final errors = await GeoDataService().updateAll();
        await _notice(
          errors.isEmpty
              ? l.prototypeAllGeodataUpdated
              : [
                  for (final entry in errors.entries)
                    '${entry.key == -1 ? l.prototypeDefaultRoutingData : _data.geodata.where((row) => row.id == entry.key).firstOrNull?.name ?? entry.key}: ${appFailureMessage(l, entry.value)}',
                ].join('\n'),
        );
      } else if (key == 'updateDefaultGeodata') {
        await GeoDataService().updateDefaults();
        await _notice(l.prototypeGeodataUpdated);
      } else if (key.startsWith('updateGeodata:')) {
        final id = int.tryParse(key.substring('updateGeodata:'.length));
        final file = id == null ? null : await _db.geoDataDao.searchRow(id);
        if (file == null || file.id <= 0) {
          throw const AppFailure(FailureCategory.conflict, 'notFound');
        }
        await GeoDataService().updateCustom(file);
        await _notice('${file.name}.dat · ${l.prototypeGeodataUpdated}');
      }
    } finally {
      _pendingUpdates.remove(key);
      _requestRefresh();
    }
  }

  Future<void> _notice(String message) async {
    if (message.isEmpty) return;
    try {
      await _notify(message);
    } catch (error, stackTrace) {
      ygLogger('Tray notification failed: $error\n$stackTrace');
    }
  }
}

enum _TrayMenuKey {
  reconnect("reconnect"),
  startVpn("startVpn"),
  stopVpn("stopVpn"),
  showApp("showApp"),
  quitApp("quitApp"),
  quitAndStopVpn("quitAndStopVpn");

  const _TrayMenuKey(this.name);

  final String name;

  static _TrayMenuKey? fromString(String name) =>
      _TrayMenuKey.values.firstWhereOrNull((value) => value.name == name);
}
