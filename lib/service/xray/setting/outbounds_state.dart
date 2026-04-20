import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/standard.dart';

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
  var network = DnsNetwork.tcp;
  var address = "";
  var port = "";
  var nonIPQuery = DnsNonIPQuery.reject;
  var dialerProxy = RoutingOutboundTag.direct.name;

  void removeWhitespace() {
    address = address.removeWhitespace;
    port = port.removeWhitespace;
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
    settings.nonIPQuery = nonIPQuery.name;
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
  final outbounds = <OutboundState>[];

  var freedom = OutboundFreedomState();
  var fragment = OutboundFragmentState();
  var blackHole = OutboundBlackHoleState();
  var dns = OutboundDnsState();

  void removeWhitespace() {
    freedom.removeWhitespace();
    dns.removeWhitespace();
  }

  void readFromXrayJson(XrayJson xrayJson) {
    if (EmptyTool.checkList(xrayJson.outbounds)) {
      final outbounds = xrayJson.outbounds!;
      for (final outbound in outbounds) {
        if (outbound.protocol == XrayOutboundProtocol.freedom.name &&
            outbound.tag == RoutingOutboundTag.direct.name) {
          _readFreedomOutbound(outbound);
          continue;
        }
        if (outbound.protocol == XrayOutboundProtocol.freedom.name &&
            outbound.tag == RoutingOutboundTag.fragment.name) {
          _readFragmentOutbound(outbound);
          continue;
        }
        if (outbound.protocol == XrayOutboundProtocol.blackhole.name &&
            outbound.tag == RoutingOutboundTag.block.name) {
          continue;
        }
        if (outbound.protocol == XrayOutboundProtocol.dns.name &&
            outbound.tag == RoutingOutboundTag.dnsOut.name) {
          _readDnsOutbound(outbound);
          continue;
        }
      }
    }
    fixDnsDialerProxy();
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
    if (EmptyTool.checkString(settings.nonIPQuery)) {
      final nonIPQuery = DnsNonIPQuery.fromString(settings.nonIPQuery!);
      if (nonIPQuery != null) {
        dns.nonIPQuery = nonIPQuery;
      }
    }
    if (EmptyTool.checkString(outbound.streamSettings?.sockopt?.dialerProxy)) {
      final dialerProxy = outbound.streamSettings!.sockopt!.dialerProxy!;
      dns.dialerProxy = dialerProxy;
    }
  }

  void fixDnsDialerProxy() {
    final dialerProxy = outboundTags
        .where((e) => e == dns.dialerProxy)
        .toList();
    if (dialerProxy.isEmpty) {
      dns.dialerProxy = RoutingOutboundTag.direct.name;
    }
  }

  List<XrayOutbound> get xrayJson {
    final outbounds = <XrayOutbound>[];
    if (this.outbounds.isNotEmpty) {
      for (final outbound in this.outbounds) {
        outbounds.add(outbound.xrayJson);
      }
    }

    final systemOutbounds = <XrayOutbound>[
      freedom.xrayJson,
      fragment.xrayJson,
      blackHole.xrayJson,
      dns.xrayJson,
    ];

    outbounds.addAll(systemOutbounds);

    return outbounds;
  }

  List<String> get outboundTags {
    final tags = <String>[
      RoutingOutboundTag.proxy.name,
      freedom.tag.name,
      fragment.tag.name,
      blackHole.tag.name,
    ];

    return tags;
  }
}
