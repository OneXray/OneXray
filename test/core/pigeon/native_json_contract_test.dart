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
      false,
      false,
      false,
      false,
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
      '{"apiVersion":2,"method":"runXray"}',
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
      'includeAllNetworks',
      'excludeLocalNetworks',
      'excludeCellularServices',
      'excludeAPNs',
      'excludeDeviceCommunication',
      'onDemandEnabled',
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

  test('runXray request uses the v2 in-memory JSON contract', () {
    final request = LibXrayInvokeRequest(
      method: LibXrayMethod.runXray,
      payload: RunXrayRequest('{"outbounds":[]}').toJson(),
    );

    expect(request.toJson(), {
      'apiVersion': 2,
      'method': 'runXray',
      'payload': {'xrayJson': '{"outbounds":[]}'},
    });
  });

  test('age subscription requests use the typed v2 contract', () {
    final convert = LibXrayInvokeRequest(
      method: LibXrayMethod.convertShareLinksToXrayJson,
      payload: ConvertShareLinksToXrayJsonRequest(
        'encrypted text',
        age: AgeDecryptConfig('AGE-SECRET-KEY-1TEST'),
      ).toJson(),
    );
    final generate = LibXrayInvokeRequest(
      method: LibXrayMethod.generateAgeKeyPair,
      payload: GenerateAgeKeyPairRequest(AgeKeyType.x25519).toJson(),
    );
    final generateHybrid = LibXrayInvokeRequest(
      method: LibXrayMethod.generateAgeKeyPair,
      payload: GenerateAgeKeyPairRequest(AgeKeyType.hybrid).toJson(),
    );

    expect(convert.toJson(), {
      'apiVersion': 2,
      'method': 'convertShareLinksToXrayJson',
      'payload': {
        'text': 'encrypted text',
        'age': {'secretKey': 'AGE-SECRET-KEY-1TEST'},
      },
    });
    expect(generate.toJson(), {
      'apiVersion': 2,
      'method': 'generateAgeKeyPair',
      'payload': {'keyType': 'x25519'},
    });
    expect(generateHybrid.toJson(), {
      'apiVersion': 2,
      'method': 'generateAgeKeyPair',
      'payload': {'keyType': 'hybrid'},
    });
  });

  test('desktop core cleanup record contains minimal process identity', () {
    const record = DesktopCoreProcessRecord(pid: 42);

    expect(DesktopCoreProcessRecord.fromJson(record.toJson()).toJson(), {
      'pid': 42,
    });
  });
}
