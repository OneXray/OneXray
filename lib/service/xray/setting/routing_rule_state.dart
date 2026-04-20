import 'package:collection/collection.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/standard.dart';

enum RoutingRuleProtocol {
  http("http"),
  tls("tls"),
  quic("quic"),
  bittorrent("bittorrent");

  const RoutingRuleProtocol(this.name);

  final String name;

  @override
  String toString() => name;

  static RoutingRuleProtocol? fromString(String name) => RoutingRuleProtocol
      .values
      .firstWhereOrNull((value) => value.name == name);

  static Set<RoutingRuleProtocol> fromStrings(List<String> strings) {
    final values = <RoutingRuleProtocol>{};
    for (final string in strings) {
      final value = RoutingRuleProtocol.fromString(string);
      if (value != null) {
        values.add(value);
      }
    }
    return values;
  }

  static List<String> toStrings(Set<RoutingRuleProtocol> values) {
    final strings = values.map((value) => value.name).toList();
    return strings;
  }
}

enum RoutingRuleNetwork {
  none(""),
  tcp("tcp"),
  udp("udp"),
  all("tcp,udp");

  const RoutingRuleNetwork(this.name);

  final String name;

  @override
  String toString() => name;

  static RoutingRuleNetwork? fromString(String name) =>
      RoutingRuleNetwork.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return RoutingRuleNetwork.values.map((e) => e.name).toList();
  }
}

class RoutingRuleState {
  var domain = <String>[];
  var ip = <String>[];
  var port = "";
  var sourcePort = "";
  var localPort = "";
  var network = RoutingRuleNetwork.none;
  var sourceIP = <String>[];
  var localIP = <String>[];
  var inboundTag = <String>{};
  var protocol = <RoutingRuleProtocol>{};
  var attrs = <String, String>{};
  var outboundTag = RoutingOutboundTag.direct.name;
  var balancerTag = "";
  var ruleTag = "custom";

  void removeWhitespace() {
    domain = domain.removeWhitespace;
    ip = ip.removeWhitespace;
    port = port.removeWhitespace;
    sourcePort = sourcePort.removeWhitespace;
    localPort = localPort.removeWhitespace;
    sourceIP = sourceIP.removeWhitespace;
    localIP = localIP.removeWhitespace;

    final newAttrs = <String, String>{};
    attrs.forEach((key, value) {
      final newKey = key.removeWhitespace;
      if (newKey.isNotEmpty) {
        final newValue = value.removeWhitespace;
        if (newValue.isNotEmpty) {
          newAttrs[newKey] = newValue;
        }
      }
    });
    attrs = newAttrs;

    outboundTag = outboundTag.removeWhitespace;
    balancerTag = balancerTag.removeWhitespace;
    ruleTag = ruleTag.removeWhitespace;
  }

  void readFromRoutingRule(XrayRoutingRule rule) {
    if (EmptyTool.checkList(rule.domain)) {
      domain = rule.domain!;
    }
    if (EmptyTool.checkList(rule.ip)) {
      ip = rule.ip!;
    }
    if (EmptyTool.checkString(rule.port)) {
      port = rule.port!;
    }
    if (EmptyTool.checkString(rule.sourcePort)) {
      sourcePort = rule.sourcePort!;
    }
    if (EmptyTool.checkString(rule.localPort)) {
      localPort = rule.localPort!;
    }
    if (EmptyTool.checkString(rule.network)) {
      final network = RoutingRuleNetwork.fromString(rule.network!);
      if (network != null) {
        this.network = network;
      }
    }
    if (EmptyTool.checkList(rule.sourceIP)) {
      sourceIP = rule.sourceIP!;
    }
    if (EmptyTool.checkList(rule.localIP)) {
      localIP = rule.localIP!;
    }
    if (EmptyTool.checkList(rule.inboundTag)) {
      inboundTag = rule.inboundTag!.toSet();
    }
    if (EmptyTool.checkList(rule.protocol)) {
      protocol = RoutingRuleProtocol.fromStrings(rule.protocol!);
    }
    if (EmptyTool.checkMap(rule.attrs)) {
      attrs = rule.attrs!;
    }
    if (EmptyTool.checkString(rule.outboundTag)) {
      outboundTag = rule.outboundTag!;
    }
    if (EmptyTool.checkString(rule.ruleTag)) {
      ruleTag = rule.ruleTag!;
    }
  }

  void fixOutboundTag(List<String> outboundTags) {
    final tags = outboundTags.where((e) => e == outboundTag).toList();
    if (tags.isEmpty) {
      outboundTag = "";
    }
  }

  XrayRoutingRule get xrayJson {
    final rule = XrayRoutingRuleStandard.standard;
    if (domain.isNotEmpty) {
      rule.domain = domain;
    }
    if (ip.isNotEmpty) {
      rule.ip = ip;
    }
    if (port.isNotEmpty) {
      rule.port = port;
    }
    if (sourcePort.isNotEmpty) {
      rule.sourcePort = sourcePort;
    }
    if (localPort.isNotEmpty) {
      rule.localPort = localPort;
    }
    if (network != RoutingRuleNetwork.none) {
      rule.network = network.name;
    }
    if (sourceIP.isNotEmpty) {
      rule.sourceIP = sourceIP;
    }
    if (localIP.isNotEmpty) {
      rule.localIP = localIP;
    }
    if (inboundTag.isNotEmpty) {
      rule.inboundTag = inboundTag.toList();
    }
    final protocol = RoutingRuleProtocol.toStrings(this.protocol);
    if (protocol.isNotEmpty) {
      rule.protocol = protocol;
    }
    if (attrs.isNotEmpty) {
      rule.attrs = attrs;
    }
    if (outboundTag.isNotEmpty) {
      rule.outboundTag = outboundTag;
    }
    if (ruleTag.isNotEmpty) {
      rule.ruleTag = ruleTag;
    }
    return rule;
  }

  static RoutingRuleState get dnsQueryRule {
    final state = RoutingRuleState();
    state.outboundTag = RoutingOutboundTag.proxy.name;
    state.inboundTag = <String>{DNSServerTag.dnsQuery};
    state.ruleTag = RoutingRuleTag.dnsQuery;
    return state;
  }

  static RoutingRuleState get dnsOutRule {
    final state = RoutingRuleState();
    state.inboundTag = <String>{RoutingInboundTag.tunIn.name};
    state.outboundTag = RoutingOutboundTag.dnsOut.name;
    state.port = "53";
    state.ruleTag = RoutingRuleTag.dnsOut;
    return state;
  }

  static RoutingRuleState get dnsDoTRule {
    final state = RoutingRuleState();
    state.inboundTag = <String>{RoutingInboundTag.tunIn.name};
    state.outboundTag = RoutingOutboundTag.proxy.name;
    state.port = "853";
    state.ruleTag = RoutingRuleTag.dnsDoT;
    return state;
  }

  static RoutingRuleState get pingRule {
    final state = RoutingRuleState();
    state.inboundTag = <String>{RoutingInboundTag.pingIn.name};
    state.outboundTag = RoutingOutboundTag.proxy.name;
    state.ruleTag = RoutingRuleTag.ping;
    return state;
  }

  String get uiTag {
    if (outboundTag.isNotEmpty) {
      return outboundTag;
    }
    return "";
  }
}
