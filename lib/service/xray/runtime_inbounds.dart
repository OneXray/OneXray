import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

abstract final class XrayRuntimeInbounds {
  static void applyToXrayJson(
    XrayJson xrayJson,
    InboundsState inbounds,
    CoreRunMode mode,
  ) {
    xrayJson.inbounds = inbounds.runtimeXrayJson(mode);
    _fixXrayRoutingInboundTags(xrayJson, mode);
  }

  static void applyToRawJson(
    Map<String, dynamic> jsonMap,
    InboundsState inbounds,
    CoreRunMode mode,
  ) {
    jsonMap["inbounds"] = inbounds
        .runtimeXrayJson(mode)
        .map((inbound) => inbound.toJson())
        .toList();
    _fixRawRoutingInboundTags(jsonMap, mode);
  }

  static void removeManagedRawInbounds(Map<String, dynamic> jsonMap) {
    jsonMap.remove("inbounds");
    _removeManagedRawRoutingRules(jsonMap);
  }

  static void _fixXrayRoutingInboundTags(XrayJson xrayJson, CoreRunMode mode) {
    final rules = xrayJson.routing?.rules;
    if (rules == null) {
      return;
    }
    for (final rule in rules) {
      rule.inboundTag = _mapInboundTag(rule.inboundTag, mode);
    }
  }

  static void _fixRawRoutingInboundTags(
    Map<String, dynamic> jsonMap,
    CoreRunMode mode,
  ) {
    final routing = jsonMap["routing"];
    if (routing is! Map) {
      return;
    }
    final rules = routing["rules"];
    if (rules is! List) {
      return;
    }
    for (final rule in rules) {
      if (rule is! Map) {
        continue;
      }
      final inboundTag = rule["inboundTag"];
      final mapped = _mapInboundTag(inboundTag, mode);
      if (mapped == null) {
        rule.remove("inboundTag");
      } else {
        rule["inboundTag"] = mapped;
      }
    }
  }

  static dynamic _mapInboundTag(dynamic inboundTag, CoreRunMode mode) {
    if (inboundTag is List) {
      final tags = <String>{};
      for (final tag in inboundTag) {
        if (tag is String) {
          tags.addAll(_mapSingleTag(tag, mode));
        }
      }
      return tags.isEmpty ? null : tags.toList();
    }
    if (inboundTag is String) {
      final tags = _mapSingleTag(inboundTag, mode);
      if (tags.isEmpty) {
        return null;
      }
      return tags.length == 1 ? tags.first : tags.toList();
    }
    return inboundTag;
  }

  static List<String> _mapSingleTag(String tag, CoreRunMode mode) {
    final tunTag = RoutingInboundTag.tunIn.name;
    final socksTag = RoutingInboundTag.socksIn.name;
    final httpTag = RoutingInboundTag.httpIn.name;
    switch (mode) {
      case CoreRunMode.tun:
        if (tag == socksTag || tag == httpTag) {
          return [tunTag];
        }
        return [tag];
      case CoreRunMode.proxy:
        if (tag == tunTag) {
          return [socksTag, httpTag];
        }
        return [tag];
    }
  }

  static void _removeManagedRawRoutingRules(Map<String, dynamic> jsonMap) {
    final routing = jsonMap["routing"];
    if (routing is! Map) {
      return;
    }
    final rules = routing["rules"];
    if (rules is! List) {
      return;
    }
    rules.removeWhere((rule) {
      if (rule is! Map) {
        return false;
      }
      final inboundTag = rule["inboundTag"];
      return _containsManagedInboundTag(inboundTag);
    });
  }

  static bool _containsManagedInboundTag(dynamic inboundTag) {
    final managed = {
      RoutingInboundTag.tunIn.name,
      RoutingInboundTag.socksIn.name,
      RoutingInboundTag.httpIn.name,
      RoutingInboundTag.pingIn.name,
    };
    if (inboundTag is List) {
      return inboundTag.any(managed.contains);
    }
    return managed.contains(inboundTag);
  }
}
