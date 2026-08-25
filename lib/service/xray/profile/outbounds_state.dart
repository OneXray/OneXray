import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/enum.dart';

class OutboundFreedomState {
  final protocol = XrayOutboundProtocol.freedom;
  final tag = RoutingOutboundTag.direct;
  var interface = "";

  void removeWhitespace() {
    interface = interface.removeWhitespace;
  }

  XrayOutbound get xrayJson {
    final outbound = XrayOutboundStandard.standard;
    outbound.protocol = protocol.name;
    outbound.tag = tag.name;
    if (interface.isNotEmpty) {
      final sockopt = XraySockoptStandard.standard;
      sockopt.interface = interface;
      final streamSettings = XrayStreamSettingsStandard.standard;
      streamSettings.sockopt = sockopt;
      outbound.streamSettings = streamSettings;
    }
    return outbound;
  }
}

class OutboundFragmentState {
  final protocol = XrayOutboundProtocol.freedom;
  final tag = RoutingOutboundTag.fragment;
  var packets = "";
  var length = "";
  var interval = "";
  var interface = "";

  void removeWhitespace() {
    packets = packets.removeWhitespace;
    length = length.removeWhitespace;
    interval = interval.removeWhitespace;
    interface = interface.removeWhitespace;
  }

  XrayOutbound get xrayJson {
    final outbound = XrayOutboundStandard.standard;
    outbound.protocol = protocol.name;
    outbound.tag = tag.name;
    if (packets.isNotEmpty || length.isNotEmpty || interval.isNotEmpty) {
      final fragment = XrayOutboundFreedomFragmentStandard.standard;
      if (EmptyTool.checkString(packets)) {
        fragment.packets = packets;
      }
      if (EmptyTool.checkString(length)) {
        fragment.length = length;
      }
      if (EmptyTool.checkString(interval)) {
        fragment.interval = interval;
      }
      final setting = XrayOutboundFreedomStandard.standard;
      setting.fragment = fragment;
      outbound.settings = setting.toJson();
    }

    if (interface.isNotEmpty) {
      final sockopt = XraySockoptStandard.standard;
      sockopt.interface = interface;
      final streamSettings = XrayStreamSettingsStandard.standard;
      streamSettings.sockopt = sockopt;
      outbound.streamSettings = streamSettings;
    }
    return outbound;
  }
}

class OutboundBlackHoleState {
  final protocol = XrayOutboundProtocol.blackhole;
  final tag = RoutingOutboundTag.block;

  XrayOutbound get xrayJson {
    final outbound = XrayOutboundStandard.standard;
    outbound.protocol = protocol.name;
    outbound.tag = tag.name;
    return outbound;
  }
}

class OutboundDnsState {
  final protocol = XrayOutboundProtocol.dns;
  final tag = RoutingOutboundTag.dnsOut;
  var network = DnsNetwork.none;
  var address = "";
  var port = "";
  var rules = defaultRules;
  var dialerProxy = RoutingOutboundTag.direct.name;

  static List<XrayOutboundDnsRule> get defaultRules => [
    XrayOutboundDnsRule("hijack", "1,28", null, null),
    XrayOutboundDnsRule("direct", null, null, null),
  ];

  void removeWhitespace() {
    address = address.removeWhitespace;
    port = port.removeWhitespace;
    dialerProxy = dialerProxy.removeWhitespace;
  }

  XrayOutbound get xrayJson {
    final outbound = XrayOutboundStandard.standard;
    outbound.protocol = protocol.name;
    outbound.tag = tag.name;
    final settings = XrayOutboundDnsStandard.standard;
    if (network != DnsNetwork.none) {
      settings.network = network.name;
    }
    if (address.isNotEmpty) {
      settings.address = address;
    }
    if (port.isNotEmpty) {
      settings.port = int.tryParse(port);
    }
    if (rules.isNotEmpty) {
      settings.rules = rules;
    }
    outbound.settings = settings.toJson();

    if (dialerProxy.isNotEmpty) {
      final sockopt = XraySockoptStandard.standard;
      sockopt.dialerProxy = dialerProxy;
      final streamSettings = XrayStreamSettingsStandard.standard;
      streamSettings.sockopt = sockopt;
      outbound.streamSettings = streamSettings;
    }

    return outbound;
  }
}

class OutboundsState {
  final outbounds = <Map<String, dynamic>>[];
  Map<String, dynamic>? finalOutbound;

  var freedom = OutboundFreedomState();
  var fragment = OutboundFragmentState();
  var blackHole = OutboundBlackHoleState();
  var dns = OutboundDnsState();

  void removeWhitespace() {
    freedom.removeWhitespace();
    fragment.removeWhitespace();
    dns.removeWhitespace();
  }

  bool readFromXrayJson(XrayJson xrayJson) {
    if (!EmptyTool.checkList(xrayJson.outbounds)) {
      return true;
    }

    final candidate = OutboundsState();
    try {
      for (final outbound in xrayJson.outbounds!) {
        requireCanonicalOutbound(outbound);
        final protocol = outboundString(outbound, 'protocol');
        final tag = outboundString(outbound, 'tag');
        if (protocol == XrayOutboundProtocol.freedom.name &&
            tag == RoutingOutboundTag.direct.name) {
          candidate._readFreedomOutbound(XrayOutbound.fromJson(outbound));
          continue;
        }
        if (protocol == XrayOutboundProtocol.freedom.name &&
            tag == RoutingOutboundTag.fragment.name) {
          candidate._readFragmentOutbound(XrayOutbound.fromJson(outbound));
          continue;
        }
        if (protocol == XrayOutboundProtocol.blackhole.name &&
            tag == RoutingOutboundTag.block.name) {
          continue;
        }
        if (protocol == XrayOutboundProtocol.dns.name &&
            tag == RoutingOutboundTag.dnsOut.name) {
          candidate._readDnsOutbound(XrayOutbound.fromJson(outbound));
          continue;
        }
        if (tag == RoutingOutboundTag.chainProxy.name) {
          candidate.finalOutbound = copyOutboundMap(outbound);
          continue;
        }
        candidate.outbounds.add(copyOutboundMap(outbound));
      }
      candidate.fixDnsDialerProxy();
    } catch (_) {
      return false;
    }

    outbounds
      ..clear()
      ..addAll(candidate.outbounds);
    finalOutbound = candidate.finalOutbound;
    freedom = candidate.freedom;
    fragment = candidate.fragment;
    blackHole = candidate.blackHole;
    dns = candidate.dns;
    return true;
  }

  void requireCanonicalProtocolSettings() {
    for (final outbound in outbounds) {
      requireCanonicalOutbound(outbound);
    }
    if (finalOutbound != null) {
      requireCanonicalOutbound(finalOutbound!);
    }
  }

  void _readFreedomOutbound(XrayOutbound outbound) {
    if (outbound.streamSettings?.sockopt == null) {
      return;
    }
    final sockopt = outbound.streamSettings!.sockopt!;
    if (sockopt.interface != null) {
      freedom.interface = sockopt.interface!;
    }
  }

  void _readFragmentOutbound(XrayOutbound outbound) {
    if (outbound.settings != null) {
      final settings = XrayOutboundFreedom.fromJson(outbound.settings!);
      if (settings.fragment != null) {
        final fragment = settings.fragment!;
        if (EmptyTool.checkString(fragment.packets)) {
          this.fragment.packets = fragment.packets!;
        }
        if (EmptyTool.checkString(fragment.length)) {
          this.fragment.length = fragment.length!;
        }
        if (EmptyTool.checkString(fragment.interval)) {
          this.fragment.interval = fragment.interval!;
        }
      }
    }
    if (outbound.streamSettings?.sockopt == null) {
      return;
    }
    final sockopt = outbound.streamSettings!.sockopt!;
    if (sockopt.interface != null) {
      fragment.interface = sockopt.interface!;
    }
  }

  void _readDnsOutbound(XrayOutbound outbound) {
    if (outbound.settings == null) {
      return;
    }
    final settings = XrayOutboundDns.fromJson(outbound.settings!);
    if (EmptyTool.checkString(settings.network)) {
      final network = DnsNetwork.fromString(settings.network!);
      if (network != null) {
        dns.network = network;
      }
    }
    if (EmptyTool.checkString(settings.address)) {
      dns.address = settings.address!;
    }
    if (settings.port != null) {
      dns.port = "${settings.port!}";
    }
    if (EmptyTool.checkList(settings.rules)) {
      dns.rules = settings.rules!;
    } else {
      dns.rules = OutboundDnsState.defaultRules;
    }
    final dialerProxy = outbound.streamSettings?.sockopt?.dialerProxy;
    if (EmptyTool.checkString(dialerProxy)) {
      dns.dialerProxy = dialerProxy!;
    }
  }

  void fixDnsDialerProxy() {
    if (!dnsDialerProxyTags.contains(dns.dialerProxy)) {
      dns.dialerProxy = RoutingOutboundTag.direct.name;
    }
  }

  List<Map<String, dynamic>> get xrayJson {
    requireCanonicalProtocolSettings();

    final outbounds = <Map<String, dynamic>>[];
    final otherOutbounds = <Map<String, dynamic>>[];
    for (final outbound in this.outbounds) {
      final copy = copyOutboundMap(outbound);
      if (outboundString(outbound, 'tag') == RoutingOutboundTag.proxy.name) {
        outbounds.add(copy);
      } else {
        otherOutbounds.add(copy);
      }
    }
    if (finalOutbound != null) {
      final finalOutbound = copyOutboundMap(this.finalOutbound!);
      setOutboundTag(finalOutbound, RoutingOutboundTag.chainProxy.name);
      removeOutboundDialerProxy(finalOutbound);
      outbounds.add(finalOutbound);
    }
    outbounds.addAll(otherOutbounds);

    final systemOutbounds = <XrayOutbound>[
      freedom.xrayJson,
      fragment.xrayJson,
      blackHole.xrayJson,
      dns.xrayJson,
    ];

    outbounds.addAll(systemOutbounds.map((outbound) => outbound.toJson()));

    return outbounds;
  }

  List<String> get outboundTags {
    final customTags = outbounds
        .map((outbound) => outboundString(outbound, 'tag'))
        .whereType<String>()
        .where((tag) => tag.isNotEmpty)
        .toList();
    final tags = <String>[
      if (!customTags.contains(RoutingOutboundTag.proxy.name))
        RoutingOutboundTag.proxy.name,
      ...customTags,
      if (finalOutbound != null) RoutingOutboundTag.chainProxy.name,
      freedom.tag.name,
      fragment.tag.name,
      blackHole.tag.name,
      dns.tag.name,
    ];

    return tags;
  }

  List<String> get dnsDialerProxyTags => outboundTags
      .where((tag) => tag != RoutingOutboundTag.fragment.name)
      .where((tag) => tag != RoutingOutboundTag.block.name)
      .where((tag) => tag != RoutingOutboundTag.dnsOut.name)
      .toList();
}
