import 'dart:convert';

import 'package:onexray/core/tools/json_tokens.dart';

enum JsonEditorKind { outbound, customRouting, advancedRouting, raw }

class JsonCompletion {
  final String label;
  final String insertText;
  final int start;
  final int end;

  const JsonCompletion({
    required this.label,
    required this.insertText,
    required this.start,
    required this.end,
  });
}

/// Small, advisory dictionaries. Unknown fields remain ordinary editable JSON;
/// only libXray decides whether protocol fields and values are valid.
class JsonEditing {
  static List<JsonCompletion> complete(
    String text,
    int offset,
    JsonEditorKind kind, {
    List<String> domainSuggestions = const [],
    List<String> ipSuggestions = const [],
  }) {
    if (offset < 0 || offset > text.length) return const [];
    final tokens = scanJsonTokens(text);
    JsonToken? target;
    for (final token in tokens) {
      if (token.kind == JsonTokenKind.string &&
          token.contentEnd == offset &&
          token.start < offset) {
        target = token;
        break;
      }
    }
    if (target == null || target.value == null) return const [];
    if (!target.closed && target.end < text.length) return const [];
    final shape = _Shape(tokens);
    final location = shape.locations[target];
    if (location == null) return const [];
    final prefix = target.value!;
    final candidates = location.isKey
        ? _fields(location.path, kind, shape)
        : _values(location.path, kind, shape, domainSuggestions, ipSuggestions);
    final existing = location.isKey
        ? shape.keys[_pathKey(location.path)] ?? const <String>{}
        : const <String>{};
    final geodata =
        !location.isKey && _geodataType(location.path, shape) != null;
    final search = geodata ? prefix.trim().toLowerCase() : prefix.toLowerCase();
    final filtered = candidates
        .toSet()
        .where(
          (candidate) =>
              candidate != prefix &&
              (geodata
                  ? candidate.toLowerCase().contains(search)
                  : candidate.toLowerCase().startsWith(search)) &&
              !existing.contains(candidate),
        )
        .toList();
    if (geodata) {
      int rank(String value) {
        final lower = value.toLowerCase();
        final code = lower.split(':').last;
        if (lower == search || code == search) return 0;
        return code.startsWith(search) ? 1 : 2;
      }

      filtered.sort((a, b) {
        final order = rank(a).compareTo(rank(b));
        return order == 0 ? a.compareTo(b) : order;
      });
    }
    return [
      for (final candidate in filtered.take(10))
        JsonCompletion(
          label: candidate,
          insertText: _stringContent(candidate),
          start: target.start + 1,
          end: offset,
        ),
    ];
  }

  static List<String> _fields(
    List<Object> path,
    JsonEditorKind kind,
    _Shape shape,
  ) {
    final custom = kind == JsonEditorKind.customRouting;
    final advanced = kind == JsonEditorKind.advancedRouting;
    if (path.isEmpty) {
      if (kind == JsonEditorKind.outbound) {
        final rootKeys = shape.keys[_pathKey(const [])] ?? const <String>{};
        if (rootKeys.any(
          (key) => key.isNotEmpty && 'outbounds'.startsWith(key),
        )) {
          return const ['outbounds'];
        }
        return _outboundFields;
      }
      if (custom) {
        return const ['name', 'outbounds', 'routing', 'dns', 'geodata'];
      }
      if (advanced) {
        return const [
          'name',
          'outbounds',
          'inbounds',
          'dns',
          'routing',
          'fakedns',
          'geodata',
        ];
      }
      return const [
        'outbounds',
        'inbounds',
        'routing',
        'dns',
        'log',
        'policy',
        'api',
        'stats',
        'metrics',
        'fakedns',
        'observatory',
        'burstObservatory',
        'transport',
      ];
    }
    if (_matches(path, ['outbounds', '*'])) {
      if (custom) return const [];
      if (advanced) {
        return const ['tag', 'protocol', 'settings', 'streamSettings'];
      }
      return _outboundFields;
    }
    if (_matches(path, ['inbounds', '*'])) {
      if (custom) return const [];
      if (advanced && shape.value([...path, 'tag']) == 'tunIn') {
        return const ['tag', 'sniffing'];
      }
      return [
        'tag',
        'protocol',
        'listen',
        'port',
        'settings',
        'sniffing',
        if (!advanced) ...['streamSettings', 'allocate'],
      ];
    }
    if (_matches(path, ['routing'])) {
      return [
        'domainStrategy',
        'rules',
        if (!custom && !advanced) ...['balancers', 'domainMatcher'],
      ];
    }
    if (_matches(path, ['routing', 'rules', '*'])) {
      return [
        'ruleTag',
        'domain',
        'ip',
        'port',
        'network',
        'protocol',
        'localOS',
        'balancerTag',
        'outboundTag',
        if (!custom) ...['inboundTag', 'localIP', 'localPort'],
        if (!custom && !advanced) ...[
          'type',
          'sourceIP',
          'sourcePort',
          'user',
          'domainMatcher',
          'attrs',
        ],
      ];
    }
    if (_matches(path, ['routing', 'balancers', '*']) &&
        kind == JsonEditorKind.raw) {
      return const ['tag', 'selector', 'strategy', 'fallbackTag'];
    }
    if (_matches(path, ['routing', 'balancers', '*', 'strategy']) &&
        kind == JsonEditorKind.raw) {
      return const ['type', 'settings'];
    }
    if (_matches(path, ['dns'])) {
      if (custom) return const ['servers'];
      return [
        'servers',
        'hosts',
        'tag',
        'disableCache',
        'disableFallback',
        'disableFallbackIfMatch',
        if (!advanced) 'queryStrategy',
      ];
    }
    if (_matches(path, ['dns', 'servers', '*'])) {
      if (custom) return const ['tag', 'address'];
      return [
        'address',
        'port',
        'domains',
        'expectIPs',
        'skipFallback',
        'clientIP',
        'tag',
        'finalQuery',
        'timeoutMs',
        if (!advanced) 'queryStrategy',
      ];
    }
    if (_matches(path, ['fakedns', '*'])) return const ['ipPool', 'poolSize'];
    if (_matches(path, ['geodata']) && (custom || advanced)) {
      return const ['assets'];
    }
    if (_matches(path, ['geodata', 'assets', '*']) && (custom || advanced)) {
      return const ['file', 'url'];
    }

    final tail = path.last;
    if (tail == 'streamSettings') {
      return advanced
          ? const ['sockopt']
          : const [
              'network',
              'security',
              'tlsSettings',
              'realitySettings',
              'wsSettings',
              'grpcSettings',
              'xhttpSettings',
              'httpupgradeSettings',
              'sockopt',
            ];
    }
    if (tail == 'sockopt') {
      return advanced
          ? const ['dialerProxy']
          : const [
              'dialerProxy',
              'mark',
              'tcpFastOpen',
              'tcpKeepAliveIdle',
              'tcpNoDelay',
              'domainStrategy',
              'interface',
            ];
    }
    if (tail == 'tlsSettings') {
      return const [
        'serverName',
        'allowInsecure',
        'alpn',
        'fingerprint',
        'certificates',
      ];
    }
    if (tail == 'realitySettings') {
      return const [
        'serverName',
        'fingerprint',
        'password',
        'publicKey',
        'shortId',
        'spiderX',
      ];
    }
    if (tail == 'wsSettings' || tail == 'httpupgradeSettings') {
      return const ['path', 'host', 'headers'];
    }
    if (tail == 'grpcSettings') {
      return const ['serviceName', 'multiMode', 'authority'];
    }
    if (tail == 'xhttpSettings') return const ['path', 'host', 'mode', 'extra'];
    if (tail == 'sniffing') {
      return const [
        'enabled',
        'routeOnly',
        'destOverride',
        'metadataOnly',
        'domainsExcluded',
        'ipsExcluded',
      ];
    }
    if (tail == 'mux') {
      return const [
        'enabled',
        'concurrency',
        'xudpConcurrency',
        'xudpProxyUDP443',
      ];
    }
    if (tail == 'proxySettings') return const ['tag', 'transportLayer'];
    if (tail == 'settings') {
      final parent = path.sublist(0, path.length - 1);
      final protocol = shape.value([...parent, 'protocol']);
      if (_matches(parent, ['inbounds', '*'])) {
        return switch (protocol) {
          'socks' => const ['auth', 'users', 'accounts', 'udp'],
          'http' => const ['users', 'accounts'],
          'tunnel' => const ['rewriteAddress', 'rewritePort', 'allowedNetwork'],
          _ => const [],
        };
      }
      return switch (protocol) {
        'vless' || 'vmess' => const ['vnext'],
        'trojan' || 'shadowsocks' || 'socks' || 'http' => const ['servers'],
        'freedom' => const [
          'domainStrategy',
          'redirect',
          'userLevel',
          'fragment',
          'noises',
        ],
        'blackhole' => const ['response'],
        'dns' => const [
          'rules',
          'rewriteNetwork',
          'rewriteAddress',
          'rewritePort',
          'userLevel',
        ],
        'wireguard' => const [
          'secretKey',
          'address',
          'peers',
          'mtu',
          'reserved',
        ],
        'loopback' => const ['inboundTag'],
        _ => const [],
      };
    }
    if (_isDnsRule(path, shape)) {
      return const ['action', 'qType', 'domain', 'rCode'];
    }
    if (_endsWith(path, ['vnext', '*'])) {
      return const ['address', 'port', 'users'];
    }
    if (_endsWith(path, ['servers', '*']) && path.contains('settings')) {
      return const ['address', 'port', 'password', 'method', 'users', 'uot'];
    }
    if (_endsWith(path, ['users', '*']) || _endsWith(path, ['accounts', '*'])) {
      return _accountFields(path, kind, shape);
    }
    if (_matches(path, ['log'])) {
      return const ['loglevel', 'access', 'error', 'dnsLog', 'maskAddress'];
    }
    return const [];
  }

  static List<String> _values(
    List<Object> path,
    JsonEditorKind kind,
    _Shape shape,
    List<String> domains,
    List<String> ips,
  ) {
    if (path.isEmpty) return const [];
    final fieldPath = path.last is int
        ? path.sublist(0, path.length - 1)
        : path;
    if (fieldPath.isEmpty) return const [];
    final field = fieldPath.last;
    final parent = fieldPath.sublist(0, fieldPath.length - 1);
    final managed =
        kind == JsonEditorKind.customRouting ||
        kind == JsonEditorKind.advancedRouting;
    final rule = _matches(parent, ['routing', 'rules', '*']);
    final dnsRule = _isDnsRule(parent, shape);
    if (field == 'outboundTag' ||
        field == 'dialerProxy' ||
        field == 'fallbackTag') {
      return [
        if (managed) ...['direct', 'block'],
        if (kind != JsonEditorKind.customRouting)
          ...shape
              .tags('outbounds')
              .where((tag) => !managed || _publicTag(tag)),
      ];
    }
    if (field == 'balancerTag') {
      return managed ? const ['proxy'] : shape.tags('balancers');
    }
    if (field == 'inboundTag') {
      return [
        ...shape
            .tags('inbounds')
            .where((tag) => !managed || _publicTag(tag) || tag == 'tunIn'),
        ...shape.dnsTags().where((tag) => !managed || _publicTag(tag)),
      ];
    }
    if (field == 'protocol') {
      if (rule) return const ['http', 'tls', 'quic', 'bittorrent'];
      if (_matches(parent, ['inbounds', '*'])) {
        return kind == JsonEditorKind.advancedRouting
            ? const ['socks', 'http', 'tunnel']
            : const [
                'socks',
                'http',
                'tunnel',
                'vless',
                'vmess',
                'trojan',
                'shadowsocks',
                'tun',
              ];
      }
      if ((parent.isEmpty && kind == JsonEditorKind.outbound) ||
          _matches(parent, ['outbounds', '*'])) {
        if (kind == JsonEditorKind.customRouting) return const [];
        return kind == JsonEditorKind.advancedRouting
            ? const ['freedom', 'blackhole', 'dns']
            : const [
                'vless',
                'vmess',
                'trojan',
                'shadowsocks',
                'socks',
                'http',
                'freedom',
                'blackhole',
                'dns',
                'wireguard',
                'loopback',
              ];
      }
    }
    final geodataType = _geodataType(path, shape);
    if (geodataType == 'domain') return domains;
    if (geodataType == 'ip') return ips;
    if (field == 'network') {
      if (rule) return const ['tcp', 'udp', 'tcp,udp'];
      if (parent.lastOrNull == 'streamSettings') {
        return const [
          'raw',
          'tcp',
          'ws',
          'grpc',
          'xhttp',
          'httpupgrade',
          'kcp',
        ];
      }
    }
    if (field == 'action' && dnsRule) {
      return const ['hijack', 'direct', 'drop', 'return'];
    }
    if (field == 'rewriteNetwork' &&
        parent.lastOrNull == 'settings' &&
        shape.value([...parent.sublist(0, parent.length - 1), 'protocol']) ==
            'dns') {
      return const ['tcp', 'udp'];
    }
    if (field == 'security' && parent.lastOrNull == 'streamSettings') {
      return const ['none', 'tls', 'reality'];
    }
    if (field == 'security' &&
        _accountFields(parent, kind, shape).contains('security')) {
      return const ['auto', 'aes-128-gcm', 'chacha20-poly1305', 'none', 'zero'];
    }
    if (field == 'domainStrategy') {
      if (kind == JsonEditorKind.customRouting) return const ['IPIfNonMatch'];
      return parent.length == 1 && parent.single == 'routing'
          ? const ['AsIs', 'IPIfNonMatch', 'IPOnDemand']
          : const ['AsIs', 'UseIP', 'UseIPv4', 'UseIPv6'];
    }
    if (field == 'queryStrategy') {
      return managed ? const [] : const ['UseIP', 'UseIPv4', 'UseIPv6'];
    }
    if (field == 'localOS' && rule) {
      return const ['ios', 'android', 'darwin', 'windows', 'linux'];
    }
    if (field == 'destOverride' && parent.lastOrNull == 'sniffing') {
      return const ['http', 'tls', 'quic', 'fakedns'];
    }
    if (field == 'type' &&
        _matches(parent, ['routing', 'balancers', '*', 'strategy'])) {
      return const ['random', 'roundRobin', 'leastPing', 'leastLoad'];
    }
    if (field == 'loglevel' && _matches(parent, ['log'])) {
      return const ['debug', 'info', 'warning', 'error', 'none'];
    }
    if (field == 'flow' &&
        _accountFields(parent, kind, shape).contains('flow')) {
      return const ['xtls-rprx-vision'];
    }
    if (field == 'encryption' &&
        _accountFields(parent, kind, shape).contains('encryption')) {
      return const ['none'];
    }
    if (field == 'auth' && parent.lastOrNull == 'settings') {
      return const ['noauth', 'password'];
    }
    return const [];
  }

  static const _outboundFields = [
    'tag',
    'protocol',
    'settings',
    'streamSettings',
    'mux',
    'sendThrough',
    'proxySettings',
  ];
}

String _stringContent(String value) {
  final encoded = jsonEncode(value);
  return encoded.substring(1, encoded.length - 1);
}

String _pathKey(List<Object> path) => jsonEncode(path);
bool _publicTag(String tag) =>
    !tag.startsWith('app-entry-') &&
    !tag.startsWith('app-exit-') &&
    tag != 'proxy';
bool _matches(List<Object> path, List<Object> pattern) =>
    path.length == pattern.length &&
    [
      for (var i = 0; i < path.length; i++)
        pattern[i] == '*' ? path[i] is int : path[i] == pattern[i],
    ].every((value) => value);
bool _endsWith(List<Object> path, List<Object> suffix) =>
    path.length >= suffix.length &&
    _matches(path.sublist(path.length - suffix.length), suffix);
bool _isDnsRule(List<Object> path, _Shape shape) =>
    _endsWith(path, ['settings', 'rules', '*']) &&
    shape.value([...path.sublist(0, path.length - 3), 'protocol']) == 'dns';

String? _geodataType(List<Object> path, _Shape shape) {
  if (path.isEmpty) return null;
  final fieldPath = path.last is int ? path.sublist(0, path.length - 1) : path;
  if (fieldPath.isEmpty) return null;
  final field = fieldPath.last;
  final parent = fieldPath.sublist(0, fieldPath.length - 1);
  final rule = _matches(parent, ['routing', 'rules', '*']);
  if (field == 'domain' && (rule || _isDnsRule(parent, shape)) ||
      field == 'domains' && _matches(parent, ['dns', 'servers', '*']) ||
      field == 'domainsExcluded' && parent.lastOrNull == 'sniffing') {
    return 'domain';
  }
  if (field == 'ip' && rule ||
      field == 'localIP' && rule ||
      field == 'sourceIP' && rule ||
      field == 'expectIPs' && _matches(parent, ['dns', 'servers', '*']) ||
      field == 'ipsExcluded' && parent.lastOrNull == 'sniffing') {
    return 'ip';
  }
  return null;
}

List<String> _accountFields(
  List<Object> path,
  JsonEditorKind kind,
  _Shape shape,
) {
  if (kind == JsonEditorKind.customRouting) return const [];
  if (_matches(path, ['inbounds', '*', 'settings', 'users', '*']) ||
      _matches(path, ['inbounds', '*', 'settings', 'accounts', '*'])) {
    final protocol = shape.value([...path.sublist(0, 2), 'protocol']);
    return protocol == 'socks' || protocol == 'http'
        ? const ['user', 'pass']
        : const [];
  }
  if (kind == JsonEditorKind.advancedRouting) return const [];
  final List<Object> owner;
  if (path.length >= 2 && path[0] == 'outbounds' && path[1] is int) {
    owner = path.sublist(0, 2);
  } else if (kind == JsonEditorKind.outbound &&
      path.firstOrNull == 'settings') {
    owner = const [];
  } else {
    return const [];
  }
  final relative = path.sublist(owner.length);
  final protocol = shape.value([...owner, 'protocol']);
  if (_matches(relative, ['settings', 'vnext', '*', 'users', '*'])) {
    return switch (protocol) {
      'vless' => const ['id', 'encryption', 'flow', 'level', 'email'],
      'vmess' => const ['id', 'security', 'level', 'email'],
      _ => const [],
    };
  }
  if (_matches(relative, ['settings', 'servers', '*', 'users', '*']) &&
      (protocol == 'socks' || protocol == 'http')) {
    return const ['user', 'pass', 'level', 'email'];
  }
  return const [];
}

class _Location {
  final List<Object> path;
  final bool isKey;
  const _Location(this.path, {this.isKey = false});
}

enum _Phase { key, colon, value, after }

class _Frame {
  final List<Object> path;
  final bool object;
  _Phase phase;
  String? key;
  int index = 0;
  _Frame(this.path, {required this.object})
    : phase = object ? _Phase.key : _Phase.value;
  List<Object>? get valuePath => phase != _Phase.value
      ? null
      : object
      ? key == null
            ? null
            : [...path, key!]
      : [...path, index];
}

/// Keeps paths for partial documents without turning suggestions into a schema.
class _Shape {
  final locations = <JsonToken, _Location>{};
  final keys = <String, Set<String>>{};
  final strings = <({List<Object> path, String value})>[];

  _Shape(List<JsonToken> tokens) {
    final stack = <_Frame>[];
    for (final token in tokens) {
      final frame = stack.lastOrNull;
      if (token.kind == JsonTokenKind.objectStart ||
          token.kind == JsonTokenKind.arrayStart) {
        final path = frame?.valuePath ?? (stack.isEmpty ? <Object>[] : null);
        if (path == null) continue;
        if (frame != null) frame.phase = _Phase.after;
        stack.add(
          _Frame(path, object: token.kind == JsonTokenKind.objectStart),
        );
      } else if (token.kind == JsonTokenKind.objectEnd ||
          token.kind == JsonTokenKind.arrayEnd) {
        if (stack.isNotEmpty) stack.removeLast();
      } else if (token.kind == JsonTokenKind.colon &&
          frame?.phase == _Phase.colon) {
        frame!.phase = _Phase.value;
      } else if (token.kind == JsonTokenKind.comma && frame != null) {
        frame.phase = frame.object ? _Phase.key : _Phase.value;
        frame.key = null;
        frame.index++;
      } else if (token.kind == JsonTokenKind.string &&
          frame?.phase == _Phase.key) {
        locations[token] = _Location(frame!.path, isKey: true);
        frame.key = token.value;
        frame.phase = _Phase.colon;
        if (token.value != null) {
          keys.putIfAbsent(_pathKey(frame.path), () => {}).add(token.value!);
        }
      } else if (token.kind == JsonTokenKind.string ||
          token.kind == JsonTokenKind.literal) {
        final path = frame?.valuePath;
        if (path == null) continue;
        locations[token] = _Location(path);
        if (token.kind == JsonTokenKind.string &&
            token.closed &&
            token.value != null) {
          strings.add((path: path, value: token.value!));
        }
        frame!.phase = _Phase.after;
      }
    }
  }

  String? value(List<Object> path) {
    final found = strings.where(
      (entry) => _pathKey(entry.path) == _pathKey(path),
    );
    return found.length == 1 ? found.single.value : null;
  }

  List<String> tags(String namespace) => [
    for (final entry in strings)
      if (_matches(
            entry.path,
            namespace == 'balancers'
                ? ['routing', 'balancers', '*', 'tag']
                : [namespace, '*', 'tag'],
          ) &&
          entry.value.isNotEmpty)
        entry.value,
  ];

  List<String> dnsTags() => [
    for (final entry in strings)
      if ((_matches(entry.path, ['dns', 'tag']) ||
              _matches(entry.path, ['dns', 'servers', '*', 'tag'])) &&
          entry.value.isNotEmpty)
        entry.value,
  ];
}
