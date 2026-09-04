import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:path/path.dart' as p;

class RouteCheckOutcome {
  final CheckRouteResponse route;
  final String path;
  final String? ruleName;
  final bool? dnsDirect;
  const RouteCheckOutcome(this.route, this.path, this.ruleName, this.dnsDirect);
}

/// Checks a prepared draft with Xray's real matcher. No settings are committed,
/// no VPN is started, and the queried target is never dispatched or persisted.
class RouteCheckService {
  Future<RouteCheckOutcome> check(
    ConnectionConfiguration configuration,
    String target, {
    RoutingProfileState? customDraft,
    int port = 443,
    String network = 'tcp',
    Future<void> Function(String)? prepareAssets,
  }) async {
    final value = target.trim();
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    final literal = InternetAddress.tryParse(value);
    final host = literal?.address ?? uri?.host;
    if (host == null ||
        host.isEmpty ||
        port < 1 ||
        port > 65535 ||
        !{'tcp', 'udp'}.contains(network)) {
      throw const FormatException('Invalid route check target');
    }
    final ip = literal ?? InternetAddress.tryParse(host);
    final plan = await ConnectionPreparation().prepare(
      configuration,
      customDraft: customDraft,
      prepareAssets: prepareAssets,
    );
    try {
      final api = AppHostApi();
      CheckRouteRequest request(String text) => CheckRouteRequest(
        xrayJson: text,
        domain: ip == null ? host : null,
        ip: ip?.address,
        port: port,
        network: network,
        inboundTag: 'tunIn',
      );
      final result = await api.checkRoute(request(plan.xrayJson));
      final json = plan.toJson();
      final entries = (json['entries'] as List)
          .map((entry) => (entry as Map)['name'] as String)
          .join(' + ');
      final exit = json['finalExit'] as Map?;
      final names = json['ruleTags'] as Map;
      bool? dnsDirect;
      if (ip == null) {
        // DNS domain selection deliberately ignores a business rule's IP/port/
        // network conditions. Use the exact generated DNS domains, with the
        // native matcher again, not a second Dart geodata/regex implementation.
        final config = jsonDecode(plan.xrayJson) as Map<String, dynamic>;
        final servers = (config['dns'] as Map)['servers'] as List;
        final domains = [
          for (final server in servers)
            if (server is Map && server['domains'] is List)
              ...server['domains'] as List,
        ];
        if (domains.isEmpty) {
          dnsDirect = false;
        } else {
          final routing = config['routing'] as Map<String, dynamic>;
          routing['domainStrategy'] = 'AsIs';
          routing['rules'] = [
            {'domain': domains, 'outboundTag': 'direct'},
            {'network': 'tcp,udp', 'balancerTag': 'proxy'},
          ];
          dnsDirect =
              (await api.checkRoute(request(jsonEncode(config)))).outboundTag ==
              'direct';
        }
      }
      return RouteCheckOutcome(
        result,
        '$entries${exit == null ? '' : ' → ${exit['name']}'}',
        (names[result.ruleTag] as Map?)?['name'] as String?,
        dnsDirect,
      );
    } finally {
      // This plan was created solely for this check, never published to the
      // coordinator or a native host. Delete only its generated private folder.
      final directory = Directory(
        p.join(VpnConstants.runDir, 'plans', plan.id),
      );
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
}
