import 'dart:async';
import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/servers/catalog.dart';
import 'package:tray_manager/tray_manager.dart';

/// Desktop-only menu content. Database streams keep names, selections and
/// available choices current; native VPN state remains owned by the coordinator.
class TrayMenuData {
  static const _maxDataItems = 10;

  ServerCatalog catalog = ServerCatalog();
  List<CoreConfigData> raws = [];
  List<RoutingProfileData> routes = [];
  List<GeoDataData> geodata = [];
  ConnectionSettings configuration = ConnectionSettings();

  static Stream<TrayMenuData> watch(AppDatabase db) => Stream.multi((sink) {
    final data = TrayMenuData();
    final subscriptions = <StreamSubscription<dynamic>>[
      ServerCatalog.watch(db).listen((catalog) {
        data.catalog = catalog;
        sink.add(data);
      }, onError: sink.addError),
      db.coreConfigDao.allRawRowsWithDataStream.listen((rows) {
        data.raws = rows;
        sink.add(data);
      }, onError: sink.addError),
      db.routingProfileDao.allRowsStream.listen((rows) {
        data.routes = rows;
        sink.add(data);
      }, onError: sink.addError),
      db.geoDataDao.publishedRowsStream.listen((rows) {
        data.geodata = rows.where((row) => row.id > 0).toList();
        sink.add(data);
      }, onError: sink.addError),
      db.connectionConfigDao.watch().listen((row) {
        try {
          data.configuration = ConnectionConfiguration.fromJson(
            jsonDecode(row.configurationJson) as Map<String, dynamic>,
          ).connection;
          sink.add(data);
        } catch (error, stackTrace) {
          sink.addError(error, stackTrace);
        }
      }, onError: sink.addError),
    ];
    sink.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });

  List<MenuItem> selectionItems(AppLocalizations l, {required bool busy}) {
    final selected = configuration.selection;
    MenuItem choice(
      String key,
      String label,
      bool checked, {
      bool enabled = true,
    }) => MenuItem.checkbox(
      key: key,
      label: label,
      checked: checked,
      disabled: busy || !enabled,
    );
    MenuItem group(String label, List<MenuItem> items, {bool enabled = true}) =>
        MenuItem.submenu(
          label: label,
          disabled: busy || !enabled || items.isEmpty,
          submenu: Menu(items: items),
        );
    bool isSelected(ServerSelection selection) =>
        !configuration.expert &&
        selected.kind == selection.kind &&
        selected.id == selection.id &&
        selected.region == selection.region;
    final sources = <int, String>{
      if (catalog.servers.any((row) => row.subId == 0))
        0: l.prototypeManualAdditions,
      for (final source in catalog.sources.take(_maxDataItems))
        source.id: source.name,
    };
    final countries = {
      for (final row in catalog.servers) row.countryCode?.toUpperCase() ?? '',
    };
    return [
      group(l.prototypeServers, [
        choice(
          'automatic',
          l.prototypeAutomaticSelection,
          isSelected(const ServerSelection.automatic()),
        ),
        group(l.prototypeBySubscription, [
          for (final source in sources.entries)
            choice(
              'source:${source.key}',
              source.value,
              isSelected(ServerSelection.source(source.key)),
            ),
        ]),
        group(l.prototypeByNodeLocation, [
          for (final country in countries.take(_maxDataItems))
            choice(
              'region:$country',
              country.isEmpty ? '—' : l.countryRegionName(country),
              isSelected(ServerSelection.region(country)),
            ),
        ]),
        group(l.prototypeServers, [
          for (final row in catalog.servers.take(_maxDataItems))
            choice(
              'server:${row.id}',
              catalog.display(row).name,
              isSelected(ServerSelection.server(row.id)),
              enabled: catalog.selectable(row),
            ),
        ]),
      ]),
      group('Raw JSON', [
        for (final row in raws.take(_maxDataItems))
          choice(
            'raw:${row.id}',
            row.name,
            configuration.expert && configuration.rawId == row.id,
          ),
      ]),
      group(l.prototypeChooseTrafficMethod, [
        choice(
          'traffic:smart',
          l.prototypeSmartRoutingRecommended,
          configuration.trafficMode == TrafficMode.smart,
        ),
        choice(
          'traffic:allVpn',
          l.prototypeAllViaVpn,
          configuration.trafficMode == TrafficMode.allVpn,
        ),
        group(l.prototypeCustomRouting, [
          for (final route in routes.take(_maxDataItems))
            choice(
              'custom:${route.id}',
              route.name,
              configuration.trafficMode == TrafficMode.custom &&
                  configuration.customId == route.id,
            ),
        ]),
      ], enabled: !configuration.expert),
    ];
  }

  List<MenuItem> updateItems(AppLocalizations l, Set<String> pending) {
    MenuItem update(String key, String label, {String? allKey}) {
      final active = pending.contains(key) || pending.contains(allKey);
      return MenuItem(
        key: key,
        label: active ? '$label · ${l.prototypePleaseWait}' : label,
        disabled: active,
      );
    }

    return [
      MenuItem.submenu(
        label: l.menuShortcutUpdateSubscriptions,
        disabled: catalog.sources.isEmpty,
        submenu: Menu(
          items: [
            update('updateSubscriptions', l.prototypeUpdateAll),
            MenuItem.separator(),
            for (final source in catalog.sources.take(_maxDataItems))
              update(
                'updateSubscription:${source.id}',
                source.name,
                allKey: 'updateSubscriptions',
              ),
          ],
        ),
      ),
      MenuItem.submenu(
        label: l.prototypeRoutingData,
        submenu: Menu(
          items: [
            update('updateGeodata', l.prototypeUpdateAll),
            MenuItem.separator(),
            update(
              'updateDefaultGeodata',
              l.prototypeDefaultRoutingData,
              allKey: 'updateGeodata',
            ),
            for (final file in geodata.take(_maxDataItems))
              update(
                'updateGeodata:${file.id}',
                '${file.name}.dat',
                allKey: 'updateGeodata',
              ),
          ],
        ),
      ),
    ];
  }
}
