import 'package:onexray/core/tools/json.dart';

const xrayConfigRootNames = <String>{
  'name',
  'log',
  'routing',
  'dns',
  'inbounds',
  'outbounds',
  'policy',
  'metrics',
  'stats',
  'fakeDns',
  'observatory',
  'burstObservatory',
};

const multiNodeOutboundRootNames = <String>{
  'name',
  'outbounds',
  'dns',
  'routing',
};

Map<String, dynamic> decodeXrayConfigMap(String text) {
  final value = JsonTool.decoder.convert(text);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Xray JSON root must be an object');
  }
  validateXrayConfigMap(value);
  return value;
}

String encodeXrayConfigMap(Map<String, dynamic> config) {
  validateXrayConfigMap(config);
  return JsonTool.encoder.convert(config);
}

Map<String, dynamic> copyXrayConfigMap(Map<String, dynamic> config) =>
    decodeXrayConfigMap(encodeXrayConfigMap(config));

void validateXrayConfigMap(Map<String, dynamic> config) {
  for (final entry in config.entries) {
    final root = entry.key;
    final value = entry.value;
    if (!xrayConfigRootNames.contains(root)) {
      throw FormatException('Unsupported Xray root: $root');
    }
    if (value == null) {
      continue;
    }
    if (root == 'name') {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('name must be a non-empty string');
      }
    } else if (root == 'inbounds' || root == 'outbounds') {
      if (value is! List<dynamic>) {
        throw FormatException('$root must be an array');
      }
    } else if (root == 'fakeDns') {
      if (value is! Map<String, dynamic> && value is! List<dynamic>) {
        throw const FormatException('fakeDns must be an object or array');
      }
    } else if (value is! Map<String, dynamic>) {
      throw FormatException('$root must be an object');
    }
  }
}

void validateMultiNodeOutboundMap(Map<String, dynamic> config) {
  for (final root in config.keys) {
    if (!multiNodeOutboundRootNames.contains(root)) {
      throw FormatException('Unsupported Multi-node Outbound root: $root');
    }
  }
  validateXrayConfigMap(config);
  final name = config['name'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('Multi-node Outbound name is required');
  }
}

String encodeXrayRootEditor(Map<String, dynamic> config, String root) {
  _requireEditableRoot(root);
  validateXrayConfigMap(config);
  return JsonTool.encoder.convert(
    config.containsKey(root) ? <String, dynamic>{root: config[root]} : {},
  );
}

Map<String, dynamic> applyXrayRootEditor(
  Map<String, dynamic> config,
  String root,
  String text,
) {
  _requireEditableRoot(root);
  validateXrayConfigMap(config);
  final value = JsonTool.decoder.convert(text);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Root editor JSON must be an object');
  }
  if (value.length > 1 || (value.isNotEmpty && !value.containsKey(root))) {
    throw FormatException('Root editor JSON may only contain $root');
  }

  final result = copyXrayConfigMap(config);
  if (value.isEmpty) {
    result.remove(root);
  } else {
    result[root] = value[root];
  }
  validateXrayConfigMap(result);
  return result;
}

Map<String, dynamic> applyMultiNodeOutboundOverlay(
  Map<String, dynamic> profile,
  Map<String, dynamic> multiNodeOutbound,
) {
  validateMultiNodeOutboundMap(multiNodeOutbound);
  final result = copyXrayConfigMap(profile);
  final overlay = copyXrayConfigMap(multiNodeOutbound);
  for (final root in const ['outbounds', 'dns', 'routing']) {
    if (!overlay.containsKey(root)) {
      continue;
    }
    final value = overlay[root];
    if (value == null) {
      result.remove(root);
    } else {
      result[root] = value;
    }
  }
  return result;
}

void _requireEditableRoot(String root) {
  if (root == 'name' || !xrayConfigRootNames.contains(root)) {
    throw FormatException('Unsupported editable Xray root: $root');
  }
}
