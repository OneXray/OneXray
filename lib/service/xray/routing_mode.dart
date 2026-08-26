import 'package:onexray/core/model/core_routing_mode.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/enum.dart';

abstract final class XrayRoutingModeFix {
  static bool applyToRawJson(
    Map<String, dynamic> jsonMap,
    CoreRoutingMode mode,
  ) {
    if (mode == CoreRoutingMode.rule) {
      return true;
    }
    final outbounds = _copyOutbounds(jsonMap['outbounds']);
    if (outbounds == null || !_tagsAreUnique(outbounds)) {
      return false;
    }

    final firstTag = switch (mode) {
      CoreRoutingMode.global => RoutingOutboundTag.proxy.name,
      CoreRoutingMode.direct => RoutingOutboundTag.direct.name,
      CoreRoutingMode.rule => throw StateError('unreachable'),
    };
    final first = _outboundByTag(outbounds, firstTag);
    if (first == null) {
      return false;
    }
    if (mode == CoreRoutingMode.global && _globalOutbounds(outbounds) == null) {
      return false;
    }
    if (mode == CoreRoutingMode.direct) {
      removeOutboundDialerProxy(first);
      removeOutboundProxyTag(first);
    }

    outbounds.remove(first);
    jsonMap['outbounds'] = <Map<String, dynamic>>[first, ...outbounds];
    jsonMap.remove('dns');
    jsonMap.remove('routing');
    return true;
  }

  static bool applyToXrayJson(XrayJson xrayJson, CoreRoutingMode mode) {
    switch (mode) {
      case CoreRoutingMode.rule:
        return true;
      case CoreRoutingMode.global:
        final copiedOutbounds = _copyOutbounds(xrayJson.outbounds);
        if (copiedOutbounds == null) {
          return false;
        }
        final outbounds = _globalOutbounds(copiedOutbounds);
        if (outbounds == null) {
          return false;
        }
        xrayJson.dns = null;
        xrayJson.routing = null;
        xrayJson.outbounds = outbounds;
        return true;
      case CoreRoutingMode.direct:
        final outbounds = _copyOutbounds(xrayJson.outbounds);
        if (outbounds == null) {
          return false;
        }
        final direct = _outboundByTag(
          outbounds,
          RoutingOutboundTag.direct.name,
        );
        if (direct == null) {
          return false;
        }
        removeOutboundDialerProxy(direct);
        removeOutboundProxyTag(direct);
        xrayJson.dns = null;
        xrayJson.routing = null;
        xrayJson.outbounds = <Map<String, dynamic>>[direct];
        return true;
    }
  }

  static bool applyGlobalToRawJson(Map<String, dynamic> jsonMap) {
    final copiedOutbounds = _copyOutbounds(jsonMap['outbounds']);
    if (copiedOutbounds == null) {
      return false;
    }
    final nextOutbounds = _globalOutbounds(copiedOutbounds);
    if (nextOutbounds == null) {
      return false;
    }

    jsonMap['outbounds'] = nextOutbounds;
    jsonMap.remove('dns');
    jsonMap.remove('routing');
    return true;
  }

  static List<Map<String, dynamic>>? _globalOutbounds(
    List<Map<String, dynamic>> outbounds,
  ) {
    final outboundsByTag = <String, Map<String, dynamic>>{};
    for (final outbound in outbounds) {
      final tag = outboundString(outbound, 'tag');
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

    final result = <Map<String, dynamic>>[];
    final visited = <String>{};
    var current = proxy;
    while (true) {
      final currentTag = outboundString(current, 'tag');
      if (currentTag == null || !visited.add(currentTag)) {
        return null;
      }
      result.add(current);

      final dialerProxy = outboundDialerProxy(current);
      final proxyTag = outboundProxyTag(current);
      if (dialerProxy?.isNotEmpty == true && proxyTag?.isNotEmpty == true) {
        return null;
      }
      final dependencyTag = dialerProxy?.isNotEmpty == true
          ? dialerProxy
          : proxyTag;
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

  static Map<String, dynamic>? _outboundByTag(
    List<Map<String, dynamic>> outbounds,
    String tag,
  ) {
    for (final outbound in outbounds) {
      if (outboundString(outbound, 'tag') == tag) {
        return outbound;
      }
    }
    return null;
  }

  static bool _tagsAreUnique(List<Map<String, dynamic>> outbounds) {
    final tags = <String>{};
    for (final outbound in outbounds) {
      final tag = outboundString(outbound, 'tag');
      if (tag == null || tag.isEmpty || !tags.add(tag)) {
        return false;
      }
    }
    return true;
  }

  static List<Map<String, dynamic>>? _copyOutbounds(Object? value) {
    if (value is! List) {
      return null;
    }
    try {
      final outbounds = <Map<String, dynamic>>[];
      for (final outbound in value) {
        if (outbound is! Map<String, dynamic>) {
          return null;
        }
        outbounds.add(copyOutboundMap(outbound));
      }
      return outbounds;
    } catch (_) {
      return null;
    }
  }
}
