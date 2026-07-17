import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/xray/profile/enum.dart';

abstract final class XrayRoutingModeFix {
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
    final rawOutbounds = jsonMap['outbounds'];
    if (rawOutbounds is! List) {
      return false;
    }
    final rawOutboundMaps = <Map>[];
    for (final outbound in rawOutbounds) {
      if (outbound is! Map) {
        return false;
      }
      rawOutboundMaps.add(outbound);
    }
    final nextOutbounds = _globalOutboundChain<Map>(
      rawOutboundMaps,
      tagOf: _rawOutboundTag,
      dependencyOf: _rawDialerProxy,
    );
    if (nextOutbounds == null) {
      return false;
    }

    jsonMap['outbounds'] = nextOutbounds;
    jsonMap.remove('dns');
    jsonMap.remove('routing');
    return true;
  }

  static List<XrayOutbound>? _globalOutbounds(List<XrayOutbound> outbounds) {
    return _globalOutboundChain<XrayOutbound>(
      outbounds,
      tagOf: (outbound) => outbound.tag,
      dependencyOf: _dialerProxy,
    );
  }

  static List<T>? _globalOutboundChain<T extends Object>(
    List<T> outbounds, {
    required String? Function(T outbound) tagOf,
    required String? Function(T outbound) dependencyOf,
  }) {
    final outboundsByTag = <String, T>{};
    for (final outbound in outbounds) {
      final tag = tagOf(outbound);
      if (tag == null || tag.isEmpty) {
        continue;
      }
      if (outboundsByTag.containsKey(tag)) {
        return null;
      }
      outboundsByTag[tag] = outbound;
    }

    final proxy = outboundsByTag[RoutingOutboundTag.proxy.name];
    if (proxy == null) {
      return null;
    }

    final result = <T>[];
    final visited = <String>{};
    var current = proxy;
    while (true) {
      final currentTag = tagOf(current);
      if (currentTag == null || !visited.add(currentTag)) {
        return null;
      }
      result.add(current);

      final dependencyTag = dependencyOf(current);
      if (dependencyTag == null || dependencyTag.isEmpty) {
        break;
      }
      final dependency = outboundsByTag[dependencyTag];
      if (dependency == null) {
        return null;
      }
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

  static String? _rawOutboundTag(Map outbound) {
    final tag = outbound['tag'];
    return tag is String ? tag : null;
  }

  static String? _rawDialerProxy(Map outbound) {
    final streamSettings = outbound['streamSettings'];
    if (streamSettings is! Map) {
      return null;
    }
    final sockopt = streamSettings['sockopt'];
    if (sockopt is! Map) {
      return null;
    }
    final dialerProxy = sockopt['dialerProxy'];
    return dialerProxy is String ? dialerProxy : null;
  }

  static String? _dialerProxy(XrayOutbound outbound) {
    return outbound.streamSettings?.sockopt?.dialerProxy;
  }

  static void _clearDialerProxy(XrayOutbound outbound) {
    outbound.streamSettings?.sockopt?.dialerProxy = null;
  }
}
