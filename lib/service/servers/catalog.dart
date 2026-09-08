import 'dart:async';

import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/servers/outbound/map.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';

/// Display data is parsed when rows change, never while building node widgets.
class ServerDisplay {
  final String name;
  final String protocol;
  final bool readable;
  const ServerDisplay(this.name, this.protocol, this.readable);

  factory ServerDisplay.fromRow(CoreConfigData row) {
    try {
      final outbound = readOutboundFromDbData(row);
      return ServerDisplay(
        outboundDisplayName(outbound),
        outboundProtocolLabel(outbound),
        row.type == 'outbound',
      );
    } on FormatException {
      return ServerDisplay(row.name, '', false);
    }
  }
}

class ServerCatalog {
  final List<CoreConfigData> servers;
  final List<SubscriptionData> sources;
  final Map<int, ServerDisplay> displays;
  final Map<int, SubscriptionData> sourcesById;

  ServerCatalog({
    List<CoreConfigData> servers = const [],
    List<SubscriptionData> sources = const [],
  }) : this._(
         List.unmodifiable(servers),
         List.unmodifiable(sources),
         Map.unmodifiable({
           for (final row in servers) row.id: ServerDisplay.fromRow(row),
         }),
         Map.unmodifiable({for (final source in sources) source.id: source}),
       );

  ServerCatalog._(this.servers, this.sources, this.displays, this.sourcesById);

  ServerCatalog copyWith({
    List<CoreConfigData>? servers,
    List<SubscriptionData>? sources,
  }) => ServerCatalog._(
    servers == null ? this.servers : List.unmodifiable(servers),
    sources == null ? this.sources : List.unmodifiable(sources),
    servers == null
        ? displays
        : Map.unmodifiable({
            for (final row in servers) row.id: ServerDisplay.fromRow(row),
          }),
    sources == null
        ? sourcesById
        : Map.unmodifiable({for (final source in sources) source.id: source}),
  );

  ServerDisplay display(CoreConfigData row) =>
      displays[row.id] ?? ServerDisplay.fromRow(row);

  bool selectable(CoreConfigData row) =>
      (row.delay == PingDelayConstants.unknown ||
          PingDelayConstants.isSuccessful(row.delay)) &&
      display(row).readable;

  static Stream<ServerCatalog> watch(AppDatabase db) => Stream.multi((sink) {
    var catalog = ServerCatalog();
    final subscriptions = [
      db.coreConfigDao.watchOutbounds().listen((rows) {
        catalog = catalog.copyWith(servers: rows);
        sink.add(catalog);
      }, onError: sink.addError),
      db.subscriptionDao.allRowsStream.listen((rows) {
        catalog = catalog.copyWith(sources: rows);
        sink.add(catalog);
      }, onError: sink.addError),
    ];
    sink.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
}
