import 'package:collection/collection.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/standard.dart';

class InboundTunState {
  final listen = NetConstants.proxyHost;
  final protocol = XrayInboundProtocol.tun;
  final settings = InboundTunSettingsState();
  final tag = RoutingInboundTag.tunIn;
  var sniffing = InboundSniffingState();

  void removeWhitespace() {
    sniffing.removeWhitespace();
  }

  void readFromXrayJson(XrayJson xrayJson) {
    final inbound = _readTunInbound(xrayJson);
    if (inbound == null) {
      return;
    }

    sniffing.readFromInbound(inbound);
  }

  XrayInbound? _readTunInbound(XrayJson xrayJson) {
    if (!EmptyTool.checkList(xrayJson.inbounds)) {
      return null;
    }
    for (final inbound in xrayJson.inbounds!) {
      if (inbound.protocol == XrayInboundProtocol.tun.name &&
          inbound.tag == RoutingInboundTag.tunIn.name) {
        return inbound;
      }
    }
    return null;
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

  XrayInboundTun get xrayJson {
    final settings = XrayInboundTunStandard.standard;
    settings.name = name;
    settings.mtu = mtu;
    return settings;
  }
}

enum InboundSniffingDestOverride {
  http("http"),
  tls("tls"),
  quic("quic");

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
  var destOverride = <InboundSniffingDestOverride>{
    InboundSniffingDestOverride.http,
    InboundSniffingDestOverride.tls,
    InboundSniffingDestOverride.quic,
  };
  var domainsExcluded = <String>[];

  void removeWhitespace() {
    domainsExcluded = domainsExcluded.removeWhitespace;
  }

  void readFromInbound(XrayInbound inbound) {
    final sniffing = inbound.sniffing;
    if (sniffing == null) {
      return;
    }

    if (sniffing.enabled != null) {
      enabled = sniffing.enabled!;
    }
    if (sniffing.routeOnly != null) {
      routeOnly = sniffing.routeOnly!;
    }
    if (EmptyTool.checkList(sniffing.destOverride)) {
      destOverride = InboundSniffingDestOverride.fromStrings(
        sniffing.destOverride!,
      );
    }
    if (EmptyTool.checkList(sniffing.domainsExcluded)) {
      domainsExcluded = sniffing.domainsExcluded!;
    }
  }

  XrayInboundSniffing get xrayJson {
    final sniffing = XrayInboundSniffingStandard.standard;
    sniffing.enabled = enabled;
    sniffing.routeOnly = routeOnly;
    if (destOverride.isNotEmpty) {
      sniffing.destOverride = InboundSniffingDestOverride.toStrings(
        destOverride,
      );
    }
    if (domainsExcluded.isNotEmpty) {
      sniffing.domainsExcluded = domainsExcluded;
    }
    return sniffing;
  }
}

class InboundPingState {
  final listen = NetConstants.proxyHost;
  var port = VpnConstants.randomPort;
  final protocol = XrayInboundProtocol.http;
  final tag = RoutingInboundTag.pingIn;

  XrayInbound get xrayJson {
    final inbound = XrayInboundStandard.standard;
    inbound.listen = listen;
    inbound.port = port;
    inbound.protocol = protocol.name;
    inbound.tag = tag.name;

    return inbound;
  }
}

class InboundsState {
  var tun = InboundTunState();
  final ping = InboundPingState();

  void removeWhitespace() {
    tun.removeWhitespace();
  }

  void readFromXrayJson(XrayJson xrayJson) {
    tun.readFromXrayJson(xrayJson);
  }

  List<XrayInbound> get xrayJson {
    return <XrayInbound>[tun.xrayJson, ping.xrayJson];
  }
}

class XrayPorts {
  String pingPort;

  XrayPorts(this.pingPort);

  static Future<XrayPorts?> getPorts() async {
    final ports = await AppHostApi().getFreePorts(1);
    if (ports.length != 1) {
      return null;
    }
    return XrayPorts("${ports[0]}");
  }
}
