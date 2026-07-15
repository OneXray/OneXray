import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/xray/profile/enum.dart';

abstract final class XrayRoutingModeFix {
  static final Set<String> _globalDependencyTags = <String>{
    RoutingOutboundTag.chainProxy.name,
    RoutingOutboundTag.fragment.name,
  };

  static bool applyToXrayJson(XrayJson xrayJson, CoreRoutingMode mode) {
    switch (mode) {
      case CoreRoutingMode.rule:
        return true;
      case CoreRoutingMode.global:
        final outbounds = _globalOutbounds(xrayJson.outbounds ?? const []);
        if (outbounds == null) {
          return false;
        }
        xrayJson.dns = null;
        xrayJson.routing = null;
        xrayJson.outbounds = outbounds;
        return true;
      case CoreRoutingMode.direct:
        final direct = _outboundByTag(
          xrayJson.outbounds ?? const [],
          RoutingOutboundTag.direct.name,
        );
        if (direct == null) {
          return false;
        }
        _clearDialerProxy(direct);
        xrayJson.dns = null;
        xrayJson.routing = null;
        xrayJson.outbounds = <XrayOutbound>[direct];
        return true;
    }
  }

  static bool applyGlobalToRawJson(Map<String, dynamic> jsonMap) {
    final xrayJson = XrayJson.fromJson(jsonMap);
    if (!applyToXrayJson(xrayJson, CoreRoutingMode.global)) {
      return false;
    }

    final rawOutbounds = jsonMap['outbounds'];
    if (rawOutbounds is! List) {
      return false;
    }
    final rawOutboundMaps = rawOutbounds.whereType<Map>().toList();
    final nextOutbounds = <Map>[];
    for (final outbound in xrayJson.outbounds ?? const <XrayOutbound>[]) {
      final tag = outbound.tag;
      if (tag == null) {
        return false;
      }
      final rawOutbound = _rawOutboundByTag(rawOutboundMaps, tag);
      if (rawOutbound == null) {
        return false;
      }
      _syncRawDialerProxy(rawOutbound, outbound);
      nextOutbounds.add(rawOutbound);
    }

    jsonMap['outbounds'] = nextOutbounds;
    jsonMap.remove('dns');
    jsonMap.remove('routing');
    return true;
  }

  static List<XrayOutbound>? _globalOutbounds(List<XrayOutbound> outbounds) {
    final proxy = _outboundByTag(outbounds, RoutingOutboundTag.proxy.name);
    if (proxy == null) {
      return null;
    }

    final result = <XrayOutbound>[proxy];
    final visited = <String>{RoutingOutboundTag.proxy.name};
    var current = proxy;
    while (true) {
      final dependencyTag = _dialerProxy(current);
      if (dependencyTag == null || dependencyTag.isEmpty) {
        break;
      }
      if (!_globalDependencyTags.contains(dependencyTag) ||
          !visited.add(dependencyTag)) {
        _clearDialerProxy(current);
        break;
      }

      final dependency = _outboundByTag(outbounds, dependencyTag);
      if (dependency == null) {
        return null;
      }
      result.add(dependency);
      current = dependency;
    }
    return result;
  }

  static XrayOutbound? _outboundByTag(
    List<XrayOutbound> outbounds,
    String tag,
  ) {
    for (final outbound in outbounds) {
      if (outbound.tag == tag) {
        return outbound;
      }
    }
    return null;
  }

  static Map? _rawOutboundByTag(List<Map> outbounds, String tag) {
    for (final outbound in outbounds) {
      if (outbound['tag'] == tag) {
        return outbound;
      }
    }
    return null;
  }

  static String? _dialerProxy(XrayOutbound outbound) {
    return outbound.streamSettings?.sockopt?.dialerProxy;
  }

  static void _clearDialerProxy(XrayOutbound outbound) {
    outbound.streamSettings?.sockopt?.dialerProxy = null;
  }

  static void _syncRawDialerProxy(Map rawOutbound, XrayOutbound outbound) {
    final dialerProxy = _dialerProxy(outbound);
    final rawStreamSettings = rawOutbound['streamSettings'];
    final rawSockopt = rawStreamSettings is Map
        ? rawStreamSettings['sockopt']
        : null;
    if (dialerProxy == null || dialerProxy.isEmpty) {
      if (rawSockopt is Map) {
        rawSockopt.remove('dialerProxy');
      }
      return;
    }

    if (rawStreamSettings is Map) {
      if (rawSockopt is Map) {
        rawSockopt['dialerProxy'] = dialerProxy;
      } else {
        rawStreamSettings['sockopt'] = <String, dynamic>{
          'dialerProxy': dialerProxy,
        };
      }
      return;
    }
    rawOutbound['streamSettings'] = <String, dynamic>{
      'sockopt': <String, dynamic>{'dialerProxy': dialerProxy},
    };
  }
}
