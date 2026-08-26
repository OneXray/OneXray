import 'dart:convert';

import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/outbound/enum.dart';

Map<String, dynamic> newOutboundMap({
  String name = XrayStateConstants.defaultName,
  String tag = 'proxy',
}) => {
  'name': name,
  'protocol': 'vless',
  'settings': {'encryption': 'none'},
  'tag': tag,
  'streamSettings': {'network': 'raw', 'security': 'none'},
};

Map<String, dynamic> copyOutboundMap(Map<String, dynamic> outbound) =>
    jsonDecode(jsonEncode(outbound)) as Map<String, dynamic>;

Map<String, dynamic> decodeSingleOutbound(String text) {
  final root = JsonTool.decoder.convert(text);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('Xray JSON root must be an object');
  }
  final outbounds = root['outbounds'];
  if (outbounds is! List<dynamic> || outbounds.length != 1) {
    throw const FormatException('Xray JSON must contain exactly one outbound');
  }
  final outbound = outbounds.single;
  if (outbound is! Map<String, dynamic>) {
    throw const FormatException('Outbound must be an object');
  }
  return copyOutboundMap(outbound);
}

String encodeSingleOutbound(Map<String, dynamic> outbound) =>
    JsonTool.encoder.convert({
      'outbounds': [outbound],
    });

String? outboundString(Map<String, dynamic> outbound, String key) {
  final value = outbound[key];
  return value is String ? value : null;
}

String? outboundNetwork(Map<String, dynamic> outbound) {
  final stream = outbound['streamSettings'];
  return stream is Map<String, dynamic>
      ? outboundString(stream, 'network')
      : null;
}

String? outboundSecurity(Map<String, dynamic> outbound) {
  final stream = outbound['streamSettings'];
  return stream is Map<String, dynamic>
      ? outboundString(stream, 'security')
      : null;
}

String outboundDisplayName(
  Map<String, dynamic> outbound, {
  String? fallback,
  bool useSendThrough = false,
}) {
  final values = <Object?>[
    outbound['name'],
    if (useSendThrough) outbound['sendThrough'],
    fallback,
    outbound['tag'],
    outbound['protocol'],
  ];
  return values.whereType<String>().firstWhere(
    (value) => value.isNotEmpty,
    orElse: () => '',
  );
}

String outboundTags(Map<String, dynamic> outbound) => [
  outboundString(outbound, 'protocol') ?? '',
  outboundNetwork(outbound) ?? '',
  outboundSecurity(outbound) ?? '',
].join(',');

void setOutboundTag(Map<String, dynamic> outbound, String tag) {
  outbound['tag'] = tag;
}

String? outboundDialerProxy(Map<String, dynamic> outbound) {
  final stream = outbound['streamSettings'];
  if (stream is! Map<String, dynamic>) {
    return null;
  }
  final sockopt = stream['sockopt'];
  if (sockopt is! Map<String, dynamic>) {
    return null;
  }
  return outboundString(sockopt, 'dialerProxy');
}

void setOutboundDialerProxy(Map<String, dynamic> outbound, String dialerProxy) {
  final stream = _objectField(outbound, 'streamSettings');
  final sockopt = _objectField(stream, 'sockopt');
  sockopt['dialerProxy'] = dialerProxy;
}

void removeOutboundDialerProxy(Map<String, dynamic> outbound) {
  final stream = outbound['streamSettings'];
  if (stream is! Map<String, dynamic>) {
    return;
  }
  final sockopt = stream['sockopt'];
  if (sockopt is Map<String, dynamic>) {
    sockopt.remove('dialerProxy');
  }
}

String? outboundProxyTag(Map<String, dynamic> outbound) {
  final settings = outbound['proxySettings'];
  return settings is Map<String, dynamic>
      ? outboundString(settings, 'tag')
      : null;
}

void removeOutboundProxyTag(Map<String, dynamic> outbound) {
  final settings = outbound['proxySettings'];
  if (settings is Map<String, dynamic>) {
    settings.remove('tag');
  }
}

void requireCanonicalOutbound(Map<String, dynamic> outbound) {
  final protocol = outboundString(outbound, 'protocol');
  if (protocol != 'vmess' && protocol != 'shadowsocks') {
    return;
  }
  final settings = outbound['settings'];
  if (settings is! Map<String, dynamic>) {
    throw const FormatException('Outbound settings must be an object');
  }
  if (protocol == 'vmess') {
    final security = settings['security'];
    if (security is! String || VMessSecurity.fromString(security) == null) {
      throw FormatException('Non-canonical VMess security: $security');
    }
    return;
  }
  final method = settings['method'];
  if (method is! String || ShadowsocksMethod.fromString(method) == null) {
    throw FormatException('Non-canonical Shadowsocks method: $method');
  }
}

Map<String, dynamic> _objectField(Map<String, dynamic> parent, String key) {
  final value = parent[key];
  if (value == null) {
    final object = <String, dynamic>{};
    parent[key] = object;
    return object;
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an object');
  }
  return value;
}
