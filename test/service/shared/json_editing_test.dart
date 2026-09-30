import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/tools/json_document.dart';
import 'package:onexray/service/shared/json_editing.dart';

List<JsonCompletion> completions(
  String marked,
  JsonEditorKind kind, {
  List<String> domains = const [],
  List<String> ips = const [],
}) {
  final offset = marked.indexOf('|');
  assert(offset >= 0);
  return JsonEditing.complete(
    marked.replaceFirst('|', ''),
    offset,
    kind,
    domainSuggestions: domains,
    ipSuggestions: ips,
  );
}

List<String> labels(String marked, JsonEditorKind kind) =>
    completions(marked, kind).map((value) => value.label).toList();

void main() {
  test('completes object keys and protocol enums in both node input forms', () {
    expect(labels('{"pro|"}', JsonEditorKind.outbound), [
      'protocol',
      'proxySettings',
    ]);
    expect(labels('{"protocol":"vl|"}', JsonEditorKind.outbound), ['vless']);
    expect(labels('{"out|"}', JsonEditorKind.outbound), ['outbounds']);
    expect(labels('{"outbounds":[],"|"}', JsonEditorKind.outbound), isEmpty);
    expect(labels('{"outbounds":[{"pro|"}]}', JsonEditorKind.outbound), [
      'protocol',
      'proxySettings',
    ]);
    expect(
      labels('{"outbounds":[{"protocol":"vm|"}]}', JsonEditorKind.outbound),
      ['vmess'],
    );
    expect(
      labels(
        '{"protocol":"vless","settings":{"vn|"}}',
        JsonEditorKind.outbound,
      ),
      ['vnext'],
    );
  });

  test('completes the core TUN DNS and WFP options only in Raw', () {
    String settings(String body, {String protocol = 'tun'}) =>
        '{"inbounds":[{"tag":"tunIn","protocol":"$protocol","settings":{$body}}]}';
    expect(labels(settings('"autoSystem|"'), JsonEditorKind.raw), [
      'autoSystemRoutingTable',
      'autoSystemDnsToGateway',
      'autoSystemWfpBlockLeak',
    ]);
    expect(
      labels(settings('"autoSystemWfpBlockLeak":["|"]'), JsonEditorKind.raw),
      ['dns', 'misconfigtun'],
    );
    expect(
      labels(settings('"autoSystemWfpBlockLeak":["mi|"]'), JsonEditorKind.raw),
      ['misconfigtun'],
    );
    expect(
      labels(settings('"autoSystem|"'), JsonEditorKind.advancedRouting),
      isEmpty,
    );
    expect(
      labels(settings('"autoSystem|"', protocol: 'socks'), JsonEditorKind.raw),
      isEmpty,
    );
    expect(
      labels(
        settings('"autoSystemWfpBlockLeak":["|"]', protocol: 'socks'),
        JsonEditorKind.raw,
      ),
      isEmpty,
    );
  });

  test('FakeDNS uses the canonical key and recognizes both pool forms', () {
    for (final kind in [JsonEditorKind.raw, JsonEditorKind.advancedRouting]) {
      expect(labels('{"fake|"}', kind), ['fakeDns']);
      for (final key in ['fakeDns', 'fakedns']) {
        expect(labels('{"$key":{"ip|"}}', kind), ['ipPool']);
        expect(labels('{"$key":[{"pool|"}]}', kind), ['poolSize']);
      }
    }
    expect(labels('{"fake|"}', JsonEditorKind.customRouting), isEmpty);
  });

  test('WireGuard removes only the obsolete settings strategy suggestions', () {
    for (final kind in [JsonEditorKind.outbound, JsonEditorKind.raw]) {
      String source(String body) => kind == JsonEditorKind.outbound
          ? '{"protocol":"wireguard",$body}'
          : '{"outbounds":[{"protocol":"wireguard",$body}]}';
      expect(labels(source('"settings":{"dom|"}'), kind), isEmpty);
      expect(
        labels(source('"settings":{"domainStrategy":"U|"}'), kind),
        isEmpty,
      );
      expect(labels(source('"settings":{"remote|"}'), kind), ['remoteDNS']);
      expect(
        labels(
          source('"streamSettings":{"sockopt":{"domainStrategy":"UseIPv|"}}'),
          kind,
        ),
        ['UseIPv4', 'UseIPv6'],
      );
    }
    expect(
      labels(
        '{"protocol":"freedom","settings":{"domainStrategy":"UseIPv|"}}',
        JsonEditorKind.outbound,
      ),
      ['UseIPv4', 'UseIPv6'],
    );
  });

  test(
    'MASQUE and XDrive suggestions preserve advanced template boundaries',
    () {
      expect(labels('{"protocol":"ma|"}', JsonEditorKind.outbound), ['masque']);
      expect(labels('{"inbounds":[{"protocol":"ma|"}]}', JsonEditorKind.raw), [
        'masque',
      ]);
      expect(labels('{"protocol":"xd|"}', JsonEditorKind.outbound), isEmpty);
      expect(
        labels(
          '{"protocol":"masque","settings":{"remote|"}}',
          JsonEditorKind.outbound,
        ),
        ['remoteDNS'],
      );
      expect(
        labels(
          '{"inbounds":[{"protocol":"masque","settings":{"users":[{"pa|"}]}}]}',
          JsonEditorKind.raw,
        ),
        ['pass'],
      );
      for (final kind in [JsonEditorKind.outbound, JsonEditorKind.raw]) {
        String source(String stream) => kind == JsonEditorKind.outbound
            ? '{"streamSettings":{$stream}}'
            : '{"outbounds":[{"streamSettings":{$stream}}]}';
        expect(labels(source('"network":"ma|"'), kind), ['masque']);
        expect(labels(source('"network":"xd|"'), kind), ['xdrive']);
        expect(labels(source('"masqueSettings":{"pa|"}'), kind), [
          'path',
          'pass',
        ]);
        expect(labels(source('"xdriveSettings":{"se|"}'), kind), [
          'service',
          'secrets',
          'segmentBytes',
        ]);
        expect(labels(source('"xdriveSettings":{"service":"G|"}'), kind), [
          'Google Drive',
        ]);
        expect(
          labels(source('"xdriveSettings":{"secrets":["|"]}'), kind),
          isEmpty,
        );
      }
      for (final body in [
        '"protocol":"ma|"',
        '"streamSettings":{"ma|"}',
        '"streamSettings":{"xdriveSettings":{"se|"}}',
        '"streamSettings":{"network":"ma|"}',
        '"streamSettings":{"network":"xd|"}',
      ]) {
        expect(
          labels('{"outbounds":[{}, {$body}]}', JsonEditorKind.advancedRouting),
          isEmpty,
        );
      }
    },
  );

  test('XDNS completes object domains and typed resolvers in UDP masks', () {
    String source(String settings) =>
        '{"outbounds":[{"streamSettings":{"finalmask":{"udp":[{"type":"XDNS","settings":{$settings}}]}}}]}';
    expect(labels(source('"ex|"'), JsonEditorKind.raw), ['extraPoll']);
    expect(labels(source('"domains":[{"na|"}]'), JsonEditorKind.raw), ['name']);
    expect(labels(source('"domains":[{"len|"}]'), JsonEditorKind.raw), [
      'lenLimit',
    ]);
    expect(labels(source('"resolvers":[{"type":"u|"}]'), JsonEditorKind.raw), [
      'udp',
    ]);
    expect(
      labels(
        source('"resolvers":[{"type":"tcp","settings":{"ad|"}}]'),
        JsonEditorKind.raw,
      ),
      ['addr'],
    );
    expect(
      labels('{"future":{"domains":[{"na|"}]}}', JsonEditorKind.raw),
      isEmpty,
    );
    expect(labels(source('"ex|"'), JsonEditorKind.advancedRouting), isEmpty);
  });

  test('noise expressions and UDPHop fields follow their UDP mask owner', () {
    String source(String type, String settings, {String network = 'udp'}) =>
        '{"streamSettings":{"finalmask":{"$network":[{"type":"$type","settings":{$settings}}]}}}';
    expect(
      labels(source('noise', '"noise":[{"ty|"}]'), JsonEditorKind.outbound),
      ['type'],
    );
    expect(
      labels(
        source('noise', '"noise":[{"type":"e|"}]'),
        JsonEditorKind.outbound,
      ),
      ['exp'],
    );
    expect(
      labels(
        source('noise', '"noise":[{"packet":"<|"}]'),
        JsonEditorKind.outbound,
      ),
      isEmpty,
    );
    expect(
      labels(
        source('xdns', '"noise":[{"type":"e|"}]'),
        JsonEditorKind.outbound,
      ),
      isEmpty,
    );
    expect(
      labels(
        source('noise', '"noise":[{"type":"e|"}]', network: 'tcp'),
        JsonEditorKind.outbound,
      ),
      isEmpty,
    );
    expect(labels(source('UDPHOP', '"re|"'), JsonEditorKind.outbound), [
      'remoteIPs',
      'remotePorts',
    ]);
    expect(labels(source('UDPHOP', '"so|"'), JsonEditorKind.outbound), isEmpty);
    expect(
      labels(source('UDPHOP', '"sockopt":{"in|"}'), JsonEditorKind.outbound),
      isEmpty,
    );
  });

  test('offers only token-end replacements, including unfinished strings', () {
    const source = '{"中文😀":true,\r\n"protocol":"vl|';
    final suggestion = completions(source, JsonEditorKind.outbound).single;
    final text = source.replaceFirst('|', '');
    expect(text.substring(suggestion.start, suggestion.end), 'vl');
    expect(suggestion.end, text.length);
    expect(suggestion.insertText, 'vless');
    expect(labels('{"protocol":"v|less"}', JsonEditorKind.outbound), isEmpty);
    expect(labels('{"pro|tocol":"vless"}', JsonEditorKind.outbound), isEmpty);
    expect(labels('{"protocol":"vl"|}', JsonEditorKind.outbound), isEmpty);
    expect(labels('{"protocol":"vl|\n}', JsonEditorKind.outbound), isEmpty);
    expect(labels(r'{"protocol":"v\|', JsonEditorKind.outbound), isEmpty);
    expect(labels(r'{"prot\u006fcol":"vl|"}', JsonEditorKind.outbound), [
      'vless',
    ]);
  });

  test(
    'does not suggest passwords, addresses, UUIDs or unknown value fields',
    () {
      for (final field in [
        'id',
        'password',
        'address',
        'serverName',
        'futureField',
      ]) {
        expect(labels('{"$field":"v|"}', JsonEditorKind.outbound), isEmpty);
      }
      expect(
        labels('{"futureField":{"anything":"|"}}', JsonEditorKind.raw),
        isEmpty,
      );
      expect(
        JsonDocument('{"futureField":{"anything":"manual"}}').syntaxError,
        isNull,
      );
    },
  );

  test(
    'custom and advanced dictionaries follow existing editor boundaries',
    () {
      expect(labels('{"lo|"}', JsonEditorKind.advancedRouting), isEmpty);
      expect(labels('{"lo|"}', JsonEditorKind.raw), ['log']);
      expect(
        labels('{"routing":{"ba|"}}', JsonEditorKind.advancedRouting),
        isEmpty,
      );
      expect(
        labels('{"routing":{"rules":[{"in|"}]}}', JsonEditorKind.customRouting),
        isEmpty,
      );
      expect(
        labels(
          '{"routing":{"rules":[{"in|"}]}}',
          JsonEditorKind.advancedRouting,
        ),
        ['inboundTag'],
      );
      expect(
        labels(
          '{"outbounds":[{}, {"protocol":"v|"}]}',
          JsonEditorKind.advancedRouting,
        ),
        isEmpty,
      );
      expect(
        labels(
          '{"outbounds":[{}, {"protocol":"fr|"}]}',
          JsonEditorKind.advancedRouting,
        ),
        ['freedom'],
      );
      expect(
        labels(
          '{"inbounds":[{"protocol":"s|"}]}',
          JsonEditorKind.advancedRouting,
        ),
        ['socks'],
      );
      expect(
        labels(
          '{"inbounds":[{"tag":"tunIn","pro|"}]}',
          JsonEditorKind.advancedRouting,
        ),
        isEmpty,
      );
      expect(
        labels('{"dns":{"qu|"}}', JsonEditorKind.advancedRouting),
        isEmpty,
      );
      expect(
        labels(
          '{"routing":{"rules":[{"protocol":["ht|"]}]}}',
          JsonEditorKind.raw,
        ),
        ['http'],
      );
    },
  );

  test('tag namespaces and generated tags stay distinct', () {
    String source(String field) =>
        '{"outbounds":[{"tag":"exit-a"}],"inbounds":[{"tag":"entry-a"}],"routing":{"balancers":[{"tag":"pool-a"}],"rules":[{"$field":"|"}]}}';
    expect(labels(source('outboundTag'), JsonEditorKind.raw), ['exit-a']);
    expect(labels(source('balancerTag'), JsonEditorKind.raw), ['pool-a']);
    expect(labels(source('inboundTag'), JsonEditorKind.raw), ['entry-a']);
    expect(labels(source('dialerProxy'), JsonEditorKind.raw), ['exit-a']);
    expect(labels(source('outboundTag'), JsonEditorKind.advancedRouting), [
      'direct',
      'block',
      'exit-a',
    ]);
    expect(labels(source('balancerTag'), JsonEditorKind.advancedRouting), [
      'proxy',
    ]);
    expect(labels(source('dialerProxy'), JsonEditorKind.advancedRouting), [
      'direct',
      'block',
      'exit-a',
    ]);
    expect(labels(source('outboundTag'), JsonEditorKind.customRouting), [
      'direct',
      'block',
    ]);
    expect(
      labels('{"routing":{"rules":[{"outboundTag":"|"}]}}', JsonEditorKind.raw),
      isEmpty,
    );
    expect(
      labels(
        '{"outbounds":[{"tag":"app-entry-0"},{"tag":"proxy"}],"routing":{"rules":[{"outboundTag":"|"}]}}',
        JsonEditorKind.advancedRouting,
      ),
      ['direct', 'block'],
    );
  });

  test(
    'DNS outbound candidates use current rules without mixing legacy policy',
    () {
      String settings(String body) =>
          '{"outbounds":[{}, {"protocol":"dns","settings":{$body}}]}';
      expect(labels(settings('"r|"'), JsonEditorKind.advancedRouting), [
        'rules',
        'rewriteNetwork',
        'rewriteAddress',
        'rewritePort',
      ]);
      expect(
        labels(
          settings('"rules":[{"action":"hijack"}],"non|"'),
          JsonEditorKind.advancedRouting,
        ),
        isEmpty,
      );
      expect(
        labels(settings('"rules":[{"q|"}]'), JsonEditorKind.advancedRouting),
        ['qType'],
      );
      expect(
        labels(
          settings('"rules":[{"action":"dr|"}]'),
          JsonEditorKind.advancedRouting,
        ),
        ['drop'],
      );
      expect(
        labels(settings('"rules":[{"action":"re|"}]'), JsonEditorKind.raw),
        ['return'],
      );
      expect(
        labels(
          settings('"rewriteNetwork":"u|"'),
          JsonEditorKind.advancedRouting,
        ),
        ['udp'],
      );
      expect(
        labels(
          '{"protocol":"dns","settings":{"ru|"}}',
          JsonEditorKind.outbound,
        ),
        ['rules'],
      );
      final domain = completions(
        settings('"rules":[{"domain":["geo|"]}]'),
        JsonEditorKind.advancedRouting,
        domains: ['geosite:CN'],
        ips: ['geoip:CN'],
      );
      expect(domain.map((value) => value.label), ['geosite:CN']);
      expect(
        JsonDocument('{"protocol":"dns","settings":{"nonIPQuery":"drop"}}')
            .syntaxError,
        isNull,
      );
    },
  );

  test('account fields follow the protocol and inbound or outbound direction', () {
    for (final protocol in ['socks', 'http']) {
      for (final field in ['users', 'accounts']) {
        expect(
          labels(
            '{"inbounds":[{"protocol":"$protocol","settings":{"$field":[{"|"}]}}]}',
            JsonEditorKind.advancedRouting,
          ),
          ['user', 'pass'],
        );
      }
      expect(
        labels(
          '{"outbounds":[{"protocol":"$protocol","settings":{"servers":[{"users":[{"|"}]}]}}]}',
          JsonEditorKind.raw,
        ),
        ['user', 'pass', 'level', 'email'],
      );
    }
    expect(
      labels(
        '{"protocol":"vless","settings":{"vnext":[{"users":[{"|"}]}]}}',
        JsonEditorKind.outbound,
      ),
      ['id', 'encryption', 'flow', 'level', 'email'],
    );
    expect(
      labels(
        '{"protocol":"vmess","settings":{"vnext":[{"users":[{"|"}]}]}}',
        JsonEditorKind.outbound,
      ),
      ['id', 'security', 'level', 'email'],
    );
    expect(
      labels(
        '{"settings":{"vnext":[{"users":[{"|"}]}]}}',
        JsonEditorKind.outbound,
      ),
      isEmpty,
    );
    expect(labels('{"future":{"users":[{"|"}]}}', JsonEditorKind.raw), isEmpty);
    expect(
      labels(
        '{"inbounds":[{"protocol":"socks","settings":{"users":[{"security":"a|"}]}}]}',
        JsonEditorKind.advancedRouting,
      ),
      isEmpty,
    );
    expect(
      labels(
        '{"protocol":"vmess","settings":{"vnext":[{"users":[{"security":"a|"}]}]}}',
        JsonEditorKind.outbound,
      ),
      ['auto', 'aes-128-gcm'],
    );
  });

  test('discovers later definitions and escapes inserted tag contents', () {
    const source =
        r'{"routing":{"rules":[{"outboundTag":"出|"}]},"outbounds":[{"tag":"出口\"😀"}]}';
    final result = completions(source, JsonEditorKind.raw).single;
    expect(result.label, '出口"😀');
    expect(result.insertText, r'出口\"😀');
    final updated = source
        .replaceFirst('|', '')
        .replaceRange(result.start, result.end, result.insertText);
    expect(JsonDocument(updated).syntaxError, isNull);
  });

  test(
    'geodata uses supplied installed candidates only in matching positions',
    () {
      const domains = ['geosite:CN', 'ext:domains.dat:LOCAL'];
      const ips = ['geoip:CN', 'ext:ips.dat:LOCAL'];
      final domain = completions(
        '{"routing":{"rules":[{"domain":["geo|"]}]}}',
        JsonEditorKind.raw,
        domains: domains,
        ips: ips,
      );
      expect(domain.map((value) => value.label), ['geosite:CN']);
      final ip = completions(
        '{"routing":{"rules":[{"ip":["geo|"]}]}}',
        JsonEditorKind.raw,
        domains: domains,
        ips: ips,
      );
      expect(ip.map((value) => value.label), ['geoip:CN']);
      expect(
        completions(
          '{"address":"geo|"}',
          JsonEditorKind.raw,
          domains: domains,
          ips: ips,
        ),
        isEmpty,
      );
      expect(
        completions(
          '{"routing":{"rules":[{"domain":["geo|"]}]}}',
          JsonEditorKind.raw,
        ),
        isEmpty,
      );
      final many = completions(
        '{"routing":{"rules":[{"domain":["geo|"]}]}}',
        JsonEditorKind.raw,
        domains: List.generate(30, (i) => 'geosite:C$i'),
      );
      expect(many.length, 10);
      final byCategory = completions(
        '{"routing":{"rules":[{"domain":["cn|"]}]}}',
        JsonEditorKind.raw,
        domains: ['geosite:BRAND@CN', 'geosite:CN', 'ext:other.dat:CN'],
      );
      expect(byCategory.map((value) => value.label), [
        'ext:other.dat:CN',
        'geosite:CN',
        'geosite:BRAND@CN',
      ]);
      final ipCategory = completions(
        '{"routing":{"rules":[{"ip":["cn|"]}]}}',
        JsonEditorKind.raw,
        domains: domains,
        ips: ['geoip:CN'],
      );
      expect(ipCategory.single.label, 'geoip:CN');
      expect(
        labels(
          '{"outbounds":[{"tag":"exit-cn"}],"routing":{"rules":[{"outboundTag":"cn|"}]}}',
          JsonEditorKind.raw,
        ),
        isEmpty,
      );
    },
  );
}
