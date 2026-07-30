import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/model.dart';

void main() {
  test('TUN and start request JSON fields match the native contract', () {
    final tun = TunJson(
      '8.8.8.8',
      '2001:4860:4860::8888',
      true,
      'dns.google',
      true,
      true,
      'OneXrayTun',
      'auto',
      true,
      true,
      [
        OnDemandRule('connect', 'wifi', ['test']),
      ],
      'allow',
      ['app.allowed'],
      ['app.disallowed'],
    );
    final request = StartVpnRequest(
      tun,
      '12000',
      XrayInboundAccount('user', 'pass'),
      '12001',
      '{"apiVersion":1,"method":"runXray"}',
    );

    expect(tun.toJson().keys.toSet(), {
      'tunDnsIPv4',
      'tunDnsIPv6',
      'enableDot',
      'dnsServerName',
      'enableIPv6',
      'metricsEnabled',
      'tunName',
      'autoOutboundsInterface',
      'onDemandEnabled',
      'disconnectOnSleep',
      'onDemandRules',
      'perAppVPNMode',
      'allowAppList',
      'disallowAppList',
    });
    expect(request.toJson().keys.toSet(), {
      'tun',
      'pingPort',
      'pingAuth',
      'metricsPort',
      'coreInvokeText',
    });
  });

  test('runtime env JSON exposes only the native-supported keys', () {
    final env = XrayEnv(
      assetLocation: '/tmp/dat',
      certLocation: '/tmp/cert',
      tunFd: '3',
    );

    expect(env.toJson().keys.toSet(), {
      'xray.location.asset',
      'xray.location.cert',
      'xray.tun.fd',
    });
  });

  test('desktop core cleanup record contains minimal process identity', () {
    const record = DesktopCoreProcessRecord(pid: 42);

    expect(DesktopCoreProcessRecord.fromJson(record.toJson()).toJson(), {
      'pid': 42,
    });
  });
}
