import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:tuple/tuple.dart';

const _reservedOutboundProtocols = <String, String>{
  'direct': 'freedom',
  'fragment': 'freedom',
  'block': 'blackhole',
  'dnsOut': 'dns',
};

Tuple2<bool, String> validateMultiNodeOutboundFields(
  Map<String, dynamic> config,
) {
  final name = config['name'];
  if (name is! String || name.isEmpty) {
    return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
  }
  try {
    validateMultiNodeOutboundMap(config);
  } on FormatException catch (error) {
    return Tuple2(false, error.message.toString());
  }

  return _validateOutboundFields(config);
}

Tuple2<bool, String> _validateOutboundFields(Map<String, dynamic> config) {
  final rawOutbounds = config['outbounds'];
  var hasProxy = false;
  final tags = <String>{};
  final outbounds = <Map<String, dynamic>>[];
  if (rawOutbounds != null) {
    for (final value in rawOutbounds as List<dynamic>) {
      if (value is! Map<String, dynamic>) {
        return const Tuple2(false, 'Outbound must be an object');
      }
      try {
        requireCanonicalOutbound(value);
      } on FormatException catch (error) {
        return Tuple2(false, error.message.toString());
      }
      final tag = outboundString(value, 'tag');
      if (tag == null || tag.isEmpty || !tags.add(tag)) {
        return Tuple2(false, appLocalizationsNoContext().validationTagUnique);
      }
      final expectedProtocol = _reservedOutboundProtocols[tag];
      if (expectedProtocol != null &&
          outboundString(value, 'protocol') != expectedProtocol) {
        return Tuple2(
          false,
          'Reserved outbound $tag must use $expectedProtocol',
        );
      }
      outbounds.add(value);
      hasProxy |= tag == 'proxy';
    }
  }
  final dependencyError = _validateOutboundDependencies(outbounds);
  if (dependencyError != null) {
    return Tuple2(false, dependencyError);
  }
  if (!hasProxy) {
    return Tuple2(false, appLocalizationsNoContext().validationProxyRequired);
  }
  return const Tuple2(true, '');
}

String? _validateOutboundDependencies(List<Map<String, dynamic>> outbounds) {
  final byTag = <String, Map<String, dynamic>>{
    for (final outbound in outbounds)
      outboundString(outbound, 'tag')!: outbound,
  };
  final states = <String, int>{};

  String? visit(String tag) {
    switch (states[tag]) {
      case 1:
        return 'Outbound dependency cycle detected at $tag';
      case 2:
        return null;
    }
    states[tag] = 1;
    final outbound = byTag[tag]!;
    final dialerProxy = outboundDialerProxy(outbound);
    final proxyTag = outboundProxyTag(outbound);
    if (dialerProxy?.isNotEmpty == true && proxyTag?.isNotEmpty == true) {
      return 'Outbound $tag has conflicting proxy dependencies';
    }
    final dependency = dialerProxy?.isNotEmpty == true
        ? dialerProxy
        : proxyTag?.isNotEmpty == true
        ? proxyTag
        : null;
    if (dependency != null) {
      if (!byTag.containsKey(dependency)) {
        return 'Outbound $tag depends on missing outbound $dependency';
      }
      final error = visit(dependency);
      if (error != null) {
        return error;
      }
    }
    states[tag] = 2;
    return null;
  }

  for (final tag in byTag.keys) {
    final error = visit(tag);
    if (error != null) {
      return error;
    }
  }
  return null;
}

Future<Tuple2<bool, String>> validateMultiNodeOutbound(
  Map<String, dynamic> multiNodeOutbound,
  Map<String, dynamic> profile,
) async {
  final fields = validateMultiNodeOutboundFields(multiNodeOutbound);
  if (!fields.item1) {
    return fields;
  }
  final materialized = applyMultiNodeOutboundOverlay(
    profile,
    multiNodeOutbound,
  );

  XrayRawFix.prepareProfileValidationConfig(materialized);
  await FileTool.checkDir(VpnConstants.runDir);
  final error = await AppHostApi().testXray(
    JsonTool.encoder.convert(materialized),
  );
  return error.isEmpty ? const Tuple2(true, '') : Tuple2(false, error);
}
