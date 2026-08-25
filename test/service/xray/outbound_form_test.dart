import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';

void main() {
  test('no-op materialize preserves the complete outbound map', () {
    final outbound = <String, dynamic>{
      'name': '  spaced name  ',
      'protocol': 'vless',
      'settings': {
        'address': ' example.com ',
        'port': 443,
        'id': 'id',
        'encryption': 'none',
        'flow': 'custom-flow',
        'editorOnly': {'keep': true},
      },
      'tag': 'proxy',
      'streamSettings': {
        'network': 'tcp',
        'security': 'tls',
        'rawSettings': {
          'header': {'type': 'http'},
        },
        'tlsSettings': {
          'serverName': ' example.com ',
          'alpn': ['h2', 'custom-alpn'],
          'editorOnly': 1,
        },
        'sockopt': {'dialerProxy': 'chain'},
        'finalmask': {'editorOnly': true},
      },
      'mux': {'enabled': true, 'editorOnly': 'keep'},
      'editorOnly': ['keep'],
    };

    final state = OutboundState(outbound);

    expect(state.network, isNull);
    expect(state.networkName, 'tcp');
    expect(state.materialize(), outbound);
  });

  test('editing one shallow leaf preserves every sibling', () {
    final outbound = <String, dynamic>{
      'name': 'node',
      'protocol': 'vless',
      'settings': {
        'address': 'example.com',
        'port': 443,
        'id': 'id',
        'encryption': 'none',
        'flow': '',
        'editorOnly': {'keep': true},
      },
      'tag': 'proxy',
      'streamSettings': {
        'network': 'ws',
        'wsSettings': {
          'path': '/old path',
          'host': 'host',
          'editorOnly': {'keep': true},
        },
        'security': 'tls',
        'tlsSettings': {'serverName': 'example.com', 'editorOnly': true},
        'sockopt': {'interface': ' interface '},
      },
      'mux': {'enabled': true},
    };
    final state = OutboundState(outbound)..wsPath = '/new path';

    final written = state.materialize();

    expect((written['streamSettings'] as Map)['wsSettings'], {
      'path': '/new path',
      'host': 'host',
      'editorOnly': {'keep': true},
    });
    expect((written['settings'] as Map)['editorOnly'], {'keep': true});
    expect(written['mux'], {'enabled': true});
    expect(
      ((written['streamSettings'] as Map)['sockopt'] as Map)['interface'],
      ' interface ',
    );
    expect(
      ((outbound['streamSettings'] as Map)['wsSettings'] as Map)['path'],
      '/old path',
    );
  });

  test('an App-unprojected settings shape is never replaced by defaults', () {
    final outbound = <String, dynamic>{
      'protocol': 'vless',
      'settings': {
        'address': ['not', 'a', 'string'],
        'id': 'id',
        'editorOnly': true,
      },
      'streamSettings': {'network': 'raw', 'security': 'none'},
    };
    final state = OutboundState(outbound)..address = 'replacement';

    expect(state.protocolFieldsProjectable, isFalse);
    expect(state.materialize(), outbound);
  });

  test(
    'explicit network switch replaces only the active transport subtree',
    () {
      final outbound = <String, dynamic>{
        'protocol': 'vless',
        'settings': {'encryption': 'none'},
        'streamSettings': {
          'network': 'ws',
          'wsSettings': {'path': '/old', 'editorOnly': true},
          'xhttpSettings': {'inactive': 'keep'},
          'security': 'none',
          'sockopt': {'dialerProxy': 'chain'},
        },
        'editorOnly': true,
      };
      final state = OutboundState(outbound);

      state.changeNetwork(StreamSettingsNetwork.grpc);
      final written = state.materialize();
      final stream = written['streamSettings'] as Map<String, dynamic>;

      expect(stream['network'], 'grpc');
      expect(stream.containsKey('wsSettings'), isFalse);
      expect(stream['grpcSettings'], isEmpty);
      expect(stream['xhttpSettings'], {'inactive': 'keep'});
      expect(stream['sockopt'], {'dialerProxy': 'chain'});
      expect(written['editorOnly'], isTrue);
    },
  );

  test(
    'explicit security switch replaces only the active security subtree',
    () {
      final outbound = <String, dynamic>{
        'protocol': 'vless',
        'settings': {'encryption': 'none'},
        'streamSettings': {
          'network': 'raw',
          'security': 'tls',
          'tlsSettings': {'serverName': 'old', 'editorOnly': true},
          'realitySettings': {'inactive': 'keep'},
          'sockopt': {'tcpFastOpen': true},
        },
      };
      final state = OutboundState(outbound);

      state.changeSecurity(StreamSettingsSecurity.reality);
      final stream =
          state.materialize()['streamSettings'] as Map<String, dynamic>;

      expect(stream['security'], 'reality');
      expect(stream.containsKey('tlsSettings'), isFalse);
      expect(stream['realitySettings'], isEmpty);
      expect(stream['sockopt'], {'tcpFastOpen': true});
    },
  );

  test(
    'explicit protocol switch replaces settings and preserves root extras',
    () {
      final outbound = <String, dynamic>{
        'name': 'node',
        'protocol': 'vless',
        'settings': {'id': 'old', 'editorOnly': true},
        'streamSettings': {
          'network': 'ws',
          'wsSettings': {'path': '/keep'},
          'security': 'none',
        },
        'mux': {'enabled': true},
      };
      final state = OutboundState(outbound);

      state.changeProtocol(XrayOutboundProtocol.vmess);
      final written = state.materialize();

      expect(written['protocol'], 'vmess');
      expect(written['settings'], {'security': 'auto'});
      expect((written['streamSettings'] as Map)['wsSettings'], {
        'path': '/keep',
      });
      expect(written['mux'], {'enabled': true});
    },
  );

  test('conflicting REALITY keys stay Map-only and unchanged', () {
    final outbound = <String, dynamic>{
      'protocol': 'vless',
      'settings': {'encryption': 'none'},
      'streamSettings': {
        'network': 'raw',
        'security': 'reality',
        'realitySettings': {
          'password': 'one',
          'publicKey': 'two',
          'serverName': 'example.com',
        },
      },
    };
    final state = OutboundState(outbound)..realityPassword = 'replacement';

    expect(state.securityFieldsProjectable, isFalse);
    expect(state.materialize(), outbound);
  });

  test('editing projected REALITY key writes password and publicKey', () {
    final state = OutboundState({
      'protocol': 'vless',
      'settings': {'encryption': 'none'},
      'streamSettings': {
        'network': 'raw',
        'security': 'reality',
        'realitySettings': {'publicKey': 'old', 'editorOnly': true},
      },
    })..realityPassword = 'new';

    final settings =
        ((state.materialize()['streamSettings'] as Map)['realitySettings']
            as Map<String, dynamic>);

    expect(settings['password'], 'new');
    expect(settings['publicKey'], 'new');
    expect(settings['editorOnly'], isTrue);
  });
}
