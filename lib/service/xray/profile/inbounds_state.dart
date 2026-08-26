import 'package:collection/collection.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/xray/tun_route.dart';

class InboundTunState {
  final listen = NetConstants.proxyHost;
  final protocol = XrayInboundProtocol.tun;
  final settings = InboundTunSettingsState();
  final tag = RoutingInboundTag.tunIn;
  var sniffing = InboundSniffingState();

  void removeWhitespace() {
    sniffing.removeWhitespace();
  }

  XrayInbound get xrayJson {
    final inbound = XrayInboundStandard.standard;
    inbound.listen = listen;
    inbound.protocol = protocol.name;
    inbound.settings = settings.xrayJson.toJson();
    inbound.tag = tag.name;
    inbound.sniffing = sniffing.xrayJson;

    return inbound;
  }
}

class InboundTunSettingsState {
  final name = "OneXrayTun";
  final mtu = 1500;
  var gateway = <String>[];
  var dns = <String>[];
  var autoSystemRoutingTable = <String>[];
  var autoOutboundsInterface = "";

  XrayInboundTun get xrayJson {
    final settings = XrayInboundTunStandard.standard;
    settings.name = name;
    settings.mtu = mtu;
    if (gateway.isNotEmpty) {
      settings.gateway = gateway;
    }
    if (dns.isNotEmpty) {
      settings.dns = dns;
    }
    if (autoSystemRoutingTable.isNotEmpty) {
      settings.autoSystemRoutingTable = autoSystemRoutingTable;
    }
    if (autoOutboundsInterface.isNotEmpty) {
      settings.autoOutboundsInterface = autoOutboundsInterface;
    }
    return settings;
  }

  void applyRouteConfig(XrayTunRouteConfig config) {
    gateway = config.gateway;
    dns = config.dns;
    autoSystemRoutingTable = config.autoSystemRoutingTable;
    autoOutboundsInterface = config.autoOutboundsInterface ?? "";
  }
}

enum InboundSniffingDestOverride {
  http("http"),
  tls("tls"),
  quic("quic"),
  fakedns("fakedns"),
  fakednsOthers("fakedns+others");

  const InboundSniffingDestOverride(this.name);

  final String name;

  @override
  String toString() => name;

  static InboundSniffingDestOverride? fromString(String name) =>
      InboundSniffingDestOverride.values.firstWhereOrNull(
        (value) => value.name == name,
      );

  static Set<InboundSniffingDestOverride> fromStrings(List<String> strings) {
    final values = <InboundSniffingDestOverride>{};
    for (final string in strings) {
      final value = InboundSniffingDestOverride.fromString(string);
      if (value != null) {
        values.add(value);
      }
    }
    return values;
  }

  static List<String> toStrings(Set<InboundSniffingDestOverride> values) {
    final strings = values.map((value) => value.name).toList();
    return strings;
  }
}

class InboundSniffingState {
  var enabled = true;
  var routeOnly = false;
  var metadataOnly = false;
  var destOverride = <InboundSniffingDestOverride>{
    InboundSniffingDestOverride.http,
    InboundSniffingDestOverride.tls,
    InboundSniffingDestOverride.quic,
  };
  var domainsExcluded = <String>[];
  var ipsExcluded = <String>[];

  void removeWhitespace() {
    domainsExcluded = domainsExcluded.removeWhitespace;
    ipsExcluded = ipsExcluded.removeWhitespace;
  }

  XrayInboundSniffing get xrayJson {
    final sniffing = XrayInboundSniffingStandard.standard;
    sniffing.enabled = enabled;
    sniffing.routeOnly = routeOnly;
    if (metadataOnly) {
      sniffing.metadataOnly = metadataOnly;
    }
    if (destOverride.isNotEmpty) {
      sniffing.destOverride = InboundSniffingDestOverride.toStrings(
        destOverride,
      );
    }
    if (domainsExcluded.isNotEmpty) {
      sniffing.domainsExcluded = domainsExcluded;
    }
    if (ipsExcluded.isNotEmpty) {
      sniffing.ipsExcluded = ipsExcluded;
    }
    return sniffing;
  }
}

class InboundPingState {
  final listen = NetConstants.proxyHost;
  var port = VpnConstants.randomPort;
  final protocol = XrayInboundProtocol.http;
  final tag = RoutingInboundTag.pingIn;
  XrayInboundAccount? auth;

  XrayInbound get xrayJson {
    final inbound = XrayInboundStandard.standard;
    inbound.listen = listen;
    inbound.port = port;
    inbound.protocol = protocol.name;
    inbound.tag = tag.name;
    if (auth?.isValid == true) {
      inbound.settings = XrayInboundHttpSettings(false, [
        XrayInboundAccount(auth!.user, auth!.pass),
      ]).toJson();
    }

    return inbound;
  }
}

class InboundsState {
  var tun = InboundTunState();
  final ping = InboundPingState();

  List<XrayInbound> get xrayJson => <XrayInbound>[tun.xrayJson, ping.xrayJson];
}

class XrayPorts {
  String pingPort;
  String metricsPort;
  final XrayInboundAccount pingAuth;

  XrayPorts(this.pingPort, this.metricsPort, this.pingAuth);

  static Future<XrayPorts?> getPorts({
    Set<int> excludedPorts = const <int>{},
  }) async {
    for (var i = 0; i < 5; i++) {
      final ports = await AppHostApi().getFreePorts(2);
      final availablePorts = ports
          .where((port) => !excludedPorts.contains(port))
          .toSet()
          .toList();
      if (availablePorts.length == 2) {
        return XrayPorts(
          "${availablePorts[0]}",
          "${availablePorts[1]}",
          XrayInboundAccountFactory.random(),
        );
      }
    }
    return null;
  }
}
