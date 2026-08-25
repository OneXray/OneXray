import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';

const outboundProtocols = <XrayOutboundProtocol>[
  XrayOutboundProtocol.vless,
  XrayOutboundProtocol.vmess,
  XrayOutboundProtocol.shadowsocks,
  XrayOutboundProtocol.trojan,
  XrayOutboundProtocol.socks,
  XrayOutboundProtocol.hysteria,
];

const outboundNetworks = <StreamSettingsNetwork>[
  StreamSettingsNetwork.raw,
  StreamSettingsNetwork.ws,
  StreamSettingsNetwork.grpc,
  StreamSettingsNetwork.httpupgrade,
  StreamSettingsNetwork.xhttp,
];

class OutboundState {
  OutboundState([Map<String, dynamic>? outbound]) {
    replaceOutbound(outbound ?? newOutboundMap());
  }

  late Map<String, dynamic> _outbound;
  final _initial = <String, Object?>{};

  var name = '';
  var tag = '';
  var protocolName = '';

  var address = '';
  var port = '';

  var vlessId = '';
  var vlessEncryption = '';
  var vlessFlow = '';

  var vmessId = '';
  var vmessSecurityName = '';

  var shadowsocksMethodName = '';
  var shadowsocksPassword = '';

  var trojanPassword = '';

  var socksUser = '';
  var socksPass = '';

  var hysteriaAuth = '';

  var networkName = '';
  var wsPath = '';
  var wsHost = '';
  var grpcAuthority = '';
  var grpcServiceName = '';
  var grpcMultiMode = false;
  var httpupgradeHost = '';
  var httpupgradePath = '';
  var xhttpHost = '';
  var xhttpPath = '';
  var xhttpMode = '';

  var securityName = '';
  var serverName = '';
  var alpnText = '';
  var fingerprint = '';
  var pinnedPeerCertSha256 = '';
  var verifyPeerCertByName = '';
  var echConfigList = '';
  var realityPassword = '';
  var shortId = '';
  var mldsa65Verify = '';
  var spiderX = '';

  var protocolFieldsProjectable = false;
  var networkFieldsProjectable = false;
  var securityFieldsProjectable = false;

  XrayOutboundProtocol? get protocol => switch (protocolName) {
    'vless' => XrayOutboundProtocol.vless,
    'vmess' => XrayOutboundProtocol.vmess,
    'shadowsocks' => XrayOutboundProtocol.shadowsocks,
    'trojan' => XrayOutboundProtocol.trojan,
    'socks' => XrayOutboundProtocol.socks,
    'hysteria' => XrayOutboundProtocol.hysteria,
    _ => null,
  };

  StreamSettingsNetwork? get network => switch (networkName) {
    'raw' => StreamSettingsNetwork.raw,
    'ws' => StreamSettingsNetwork.ws,
    'grpc' => StreamSettingsNetwork.grpc,
    'httpupgrade' => StreamSettingsNetwork.httpupgrade,
    'xhttp' => StreamSettingsNetwork.xhttp,
    'hysteria' => StreamSettingsNetwork.hysteria,
    _ => null,
  };

  StreamSettingsSecurity? get security => switch (securityName) {
    'none' => StreamSettingsSecurity.none,
    'tls' => StreamSettingsSecurity.tls,
    'reality' => StreamSettingsSecurity.reality,
    _ => null,
  };

  VMessSecurity? get vmessSecurity =>
      VMessSecurity.fromString(vmessSecurityName);

  ShadowsocksMethod? get shadowsocksMethod =>
      ShadowsocksMethod.fromString(shadowsocksMethodName);

  bool get isHysteria => protocol == XrayOutboundProtocol.hysteria;

  void replaceOutbound(Map<String, dynamic> outbound) {
    _outbound = copyOutboundMap(outbound);
    _project();
  }

  Map<String, dynamic> materialize() {
    final outbound = copyOutboundMap(_outbound);

    _patch(outbound, 'name', name, 'name');
    _patch(outbound, 'tag', tag, 'tag');
    _patchProtocolSettings(outbound);
    _patchNetworkSettings(outbound);
    _patchSecuritySettings(outbound);

    _outbound = outbound;
    _rememberInitialValues();
    return copyOutboundMap(outbound);
  }

  void changeProtocol(XrayOutboundProtocol value) {
    if (!outboundProtocols.contains(value) || protocol == value) {
      return;
    }
    final wasHysteria = isHysteria;
    materialize();
    _outbound['protocol'] = value.name;
    _outbound['settings'] = _newProtocolSettings(value);
    if (value == XrayOutboundProtocol.hysteria) {
      _setHysteriaStream();
    } else if (wasHysteria) {
      _resetHysteriaStream();
    }
    _project();
  }

  void changeNetwork(StreamSettingsNetwork value) {
    if (!outboundNetworks.contains(value) || network == value) {
      return;
    }
    materialize();
    final stream = _streamForSwitch();
    _removeActiveNetworkSettings(stream, networkName);
    stream['network'] = value.name;
    final settingsKey = _networkSettingsKey(value.name);
    if (settingsKey != null) {
      stream[settingsKey] = value == StreamSettingsNetwork.xhttp
          ? <String, dynamic>{'mode': 'auto'}
          : <String, dynamic>{};
    }
    _project();
  }

  void changeSecurity(StreamSettingsSecurity value) {
    if (security == value) {
      return;
    }
    materialize();
    final stream = _streamForSwitch();
    _removeActiveSecuritySettings(stream, securityName);
    stream['security'] = value.name;
    final settingsKey = _securitySettingsKey(value.name);
    if (settingsKey != null) {
      stream[settingsKey] = <String, dynamic>{};
    }
    _project();
  }

  void selectVmessSecurity(VMessSecurity value) {
    vmessSecurityName = value.name;
  }

  void selectShadowsocksMethod(ShadowsocksMethod value) {
    shadowsocksMethodName = value.name;
  }

  void _project() {
    _resetForm();
    name = outboundDisplayName(_outbound);
    tag = _string(_outbound, 'tag');
    protocolName = _string(_outbound, 'protocol');

    protocolFieldsProjectable = _projectProtocolSettings();
    networkFieldsProjectable = _projectNetworkSettings();
    securityFieldsProjectable = _projectSecuritySettings();
    _rememberInitialValues();
  }

  bool _projectProtocolSettings() {
    final settings = _outbound['settings'];
    if (settings is! Map<String, dynamic>) {
      return false;
    }
    if (!_validString(settings, 'address') || !_validPort(settings, 'port')) {
      return false;
    }
    address = _string(settings, 'address');
    port = _port(settings, 'port');

    switch (protocol) {
      case XrayOutboundProtocol.vless:
        if (!_validStrings(settings, const ['id', 'encryption', 'flow'])) {
          return false;
        }
        vlessId = _string(settings, 'id');
        vlessEncryption = _string(settings, 'encryption');
        vlessFlow = _string(settings, 'flow');
        return true;
      case XrayOutboundProtocol.vmess:
        if (!_validStrings(settings, const ['id', 'security'])) {
          return false;
        }
        vmessId = _string(settings, 'id');
        vmessSecurityName = _string(settings, 'security');
        return true;
      case XrayOutboundProtocol.shadowsocks:
        if (!_validStrings(settings, const ['method', 'password'])) {
          return false;
        }
        shadowsocksMethodName = _string(settings, 'method');
        shadowsocksPassword = _string(settings, 'password');
        return true;
      case XrayOutboundProtocol.trojan:
        if (!_validString(settings, 'password')) {
          return false;
        }
        trojanPassword = _string(settings, 'password');
        return true;
      case XrayOutboundProtocol.socks:
        if (!_validStrings(settings, const ['user', 'pass'])) {
          return false;
        }
        socksUser = _string(settings, 'user');
        socksPass = _string(settings, 'pass');
        return true;
      case XrayOutboundProtocol.hysteria:
        if (settings['version'] != 2 || !_validHysteriaStream()) {
          return false;
        }
        final stream = _outbound['streamSettings'] as Map<String, dynamic>;
        final hysteriaSettings =
            stream['hysteriaSettings'] as Map<String, dynamic>;
        hysteriaAuth = _string(hysteriaSettings, 'auth');
        return true;
      case null:
      case XrayOutboundProtocol.blackhole:
      case XrayOutboundProtocol.dns:
      case XrayOutboundProtocol.freedom:
        return false;
    }
  }

  bool _projectNetworkSettings() {
    final stream = _outbound['streamSettings'];
    if (stream is! Map<String, dynamic>) {
      networkName = '';
      return false;
    }
    networkName = _string(stream, 'network');
    switch (network) {
      case StreamSettingsNetwork.raw:
        return true;
      case StreamSettingsNetwork.ws:
        final settings = _optionalObject(stream, 'wsSettings');
        if (settings == null ||
            !_validStrings(settings, const ['path', 'host'])) {
          return false;
        }
        wsPath = _string(settings, 'path');
        wsHost = _string(settings, 'host');
        return true;
      case StreamSettingsNetwork.grpc:
        final settings = _optionalObject(stream, 'grpcSettings');
        if (settings == null ||
            !_validStrings(settings, const ['authority', 'serviceName']) ||
            !_validBool(settings, 'multiMode')) {
          return false;
        }
        grpcAuthority = _string(settings, 'authority');
        grpcServiceName = _string(settings, 'serviceName');
        grpcMultiMode = settings['multiMode'] == true;
        return true;
      case StreamSettingsNetwork.httpupgrade:
        final settings = _optionalObject(stream, 'httpupgradeSettings');
        if (settings == null ||
            !_validStrings(settings, const ['host', 'path'])) {
          return false;
        }
        httpupgradeHost = _string(settings, 'host');
        httpupgradePath = _string(settings, 'path');
        return true;
      case StreamSettingsNetwork.xhttp:
        final settings = _optionalObject(stream, 'xhttpSettings');
        if (settings == null ||
            !_validStrings(settings, const ['host', 'path', 'mode'])) {
          return false;
        }
        xhttpHost = _string(settings, 'host');
        xhttpPath = _string(settings, 'path');
        xhttpMode = _string(settings, 'mode');
        return true;
      case StreamSettingsNetwork.hysteria:
        final settings = _optionalObject(stream, 'hysteriaSettings');
        return settings != null &&
            settings['version'] == 2 &&
            _validString(settings, 'auth');
      case null:
        return false;
    }
  }

  bool _projectSecuritySettings() {
    final stream = _outbound['streamSettings'];
    if (stream is! Map<String, dynamic>) {
      securityName = '';
      return false;
    }
    securityName = _string(stream, 'security');
    switch (security) {
      case StreamSettingsSecurity.none:
        return true;
      case StreamSettingsSecurity.tls:
        final settings = _optionalObject(stream, 'tlsSettings');
        if (settings == null ||
            !_validStrings(settings, const [
              'serverName',
              'fingerprint',
              'pinnedPeerCertSha256',
              'verifyPeerCertByName',
              'echConfigList',
            ]) ||
            !_validStringList(settings, 'alpn')) {
          return false;
        }
        serverName = _string(settings, 'serverName');
        fingerprint = _string(settings, 'fingerprint');
        pinnedPeerCertSha256 = _string(settings, 'pinnedPeerCertSha256');
        verifyPeerCertByName = _string(settings, 'verifyPeerCertByName');
        echConfigList = _string(settings, 'echConfigList');
        alpnText = _stringList(settings, 'alpn').join(',');
        return true;
      case StreamSettingsSecurity.reality:
        final settings = _optionalObject(stream, 'realitySettings');
        if (settings == null ||
            !_validStrings(settings, const [
              'serverName',
              'fingerprint',
              'password',
              'publicKey',
              'shortId',
              'mldsa65Verify',
              'spiderX',
            ])) {
          return false;
        }
        final password = _string(settings, 'password');
        final publicKey = _string(settings, 'publicKey');
        if (password.isNotEmpty &&
            publicKey.isNotEmpty &&
            password != publicKey) {
          return false;
        }
        serverName = _string(settings, 'serverName');
        fingerprint = _string(settings, 'fingerprint');
        realityPassword = password.isNotEmpty ? password : publicKey;
        shortId = _string(settings, 'shortId');
        mldsa65Verify = _string(settings, 'mldsa65Verify');
        spiderX = _string(settings, 'spiderX');
        return true;
      case null:
        return false;
    }
  }

  void _patchProtocolSettings(Map<String, dynamic> outbound) {
    if (!protocolFieldsProjectable) {
      return;
    }
    final settings = outbound['settings'] as Map<String, dynamic>;
    _patch(settings, 'address', address, 'address');
    _patch(settings, 'port', port, 'port', value: int.tryParse(port));

    switch (protocol) {
      case XrayOutboundProtocol.vless:
        _patch(settings, 'id', vlessId, 'vlessId');
        _patch(settings, 'encryption', vlessEncryption, 'vlessEncryption');
        _patch(settings, 'flow', vlessFlow, 'vlessFlow');
        break;
      case XrayOutboundProtocol.vmess:
        _patch(settings, 'id', vmessId, 'vmessId');
        _patch(settings, 'security', vmessSecurityName, 'vmessSecurityName');
        break;
      case XrayOutboundProtocol.shadowsocks:
        _patch(
          settings,
          'method',
          shadowsocksMethodName,
          'shadowsocksMethodName',
        );
        _patch(
          settings,
          'password',
          shadowsocksPassword,
          'shadowsocksPassword',
        );
        break;
      case XrayOutboundProtocol.trojan:
        _patch(settings, 'password', trojanPassword, 'trojanPassword');
        break;
      case XrayOutboundProtocol.socks:
        _patch(settings, 'user', socksUser, 'socksUser');
        _patch(settings, 'pass', socksPass, 'socksPass');
        break;
      case XrayOutboundProtocol.hysteria:
        final stream = outbound['streamSettings'] as Map<String, dynamic>;
        final hysteriaSettings =
            stream['hysteriaSettings'] as Map<String, dynamic>;
        _patch(hysteriaSettings, 'auth', hysteriaAuth, 'hysteriaAuth');
        break;
      case null:
      case XrayOutboundProtocol.blackhole:
      case XrayOutboundProtocol.dns:
      case XrayOutboundProtocol.freedom:
        break;
    }
  }

  void _patchNetworkSettings(Map<String, dynamic> outbound) {
    if (!networkFieldsProjectable) {
      return;
    }
    final stream = outbound['streamSettings'] as Map<String, dynamic>;
    switch (network) {
      case StreamSettingsNetwork.ws:
        final settings = _objectForPatch(stream, 'wsSettings');
        _patch(settings, 'path', wsPath, 'wsPath');
        _patch(settings, 'host', wsHost, 'wsHost');
        break;
      case StreamSettingsNetwork.grpc:
        final settings = _objectForPatch(stream, 'grpcSettings');
        _patch(settings, 'authority', grpcAuthority, 'grpcAuthority');
        _patch(settings, 'serviceName', grpcServiceName, 'grpcServiceName');
        _patch(settings, 'multiMode', grpcMultiMode, 'grpcMultiMode');
        break;
      case StreamSettingsNetwork.httpupgrade:
        final settings = _objectForPatch(stream, 'httpupgradeSettings');
        _patch(settings, 'host', httpupgradeHost, 'httpupgradeHost');
        _patch(settings, 'path', httpupgradePath, 'httpupgradePath');
        break;
      case StreamSettingsNetwork.xhttp:
        final settings = _objectForPatch(stream, 'xhttpSettings');
        _patch(settings, 'host', xhttpHost, 'xhttpHost');
        _patch(settings, 'path', xhttpPath, 'xhttpPath');
        _patch(settings, 'mode', xhttpMode, 'xhttpMode');
        break;
      case StreamSettingsNetwork.raw:
      case StreamSettingsNetwork.hysteria:
      case null:
        break;
    }
  }

  void _patchSecuritySettings(Map<String, dynamic> outbound) {
    if (!securityFieldsProjectable) {
      return;
    }
    final stream = outbound['streamSettings'] as Map<String, dynamic>;
    switch (security) {
      case StreamSettingsSecurity.tls:
        final settings = _objectForPatch(stream, 'tlsSettings');
        _patch(settings, 'serverName', serverName, 'serverName');
        _patch(settings, 'fingerprint', fingerprint, 'fingerprint');
        _patch(
          settings,
          'pinnedPeerCertSha256',
          pinnedPeerCertSha256,
          'pinnedPeerCertSha256',
        );
        _patch(
          settings,
          'verifyPeerCertByName',
          verifyPeerCertByName,
          'verifyPeerCertByName',
        );
        _patch(settings, 'echConfigList', echConfigList, 'echConfigList');
        _patch(
          settings,
          'alpn',
          alpnText,
          'alpnText',
          value: alpnText.isEmpty ? <String>[] : alpnText.split(','),
        );
        break;
      case StreamSettingsSecurity.reality:
        final settings = _objectForPatch(stream, 'realitySettings');
        _patch(settings, 'serverName', serverName, 'serverName');
        _patch(settings, 'fingerprint', fingerprint, 'fingerprint');
        if (_changed('realityPassword', realityPassword)) {
          settings['password'] = realityPassword;
          settings['publicKey'] = realityPassword;
        }
        _patch(settings, 'shortId', shortId, 'shortId');
        _patch(settings, 'mldsa65Verify', mldsa65Verify, 'mldsa65Verify');
        _patch(settings, 'spiderX', spiderX, 'spiderX');
        break;
      case StreamSettingsSecurity.none:
      case null:
        break;
    }
  }

  void _setHysteriaStream() {
    final stream = _streamForSwitch();
    _removeActiveNetworkSettings(stream, _string(stream, 'network'));
    _removeActiveSecuritySettings(stream, _string(stream, 'security'));
    stream['network'] = 'hysteria';
    stream['hysteriaSettings'] = <String, dynamic>{'version': 2};
    stream['security'] = 'tls';
    stream['tlsSettings'] = <String, dynamic>{};
  }

  void _resetHysteriaStream() {
    final stream = _streamForSwitch();
    if (_string(stream, 'network') == 'hysteria') {
      stream.remove('hysteriaSettings');
      stream['network'] = 'raw';
    }
    if (_string(stream, 'security') == 'tls') {
      stream.remove('tlsSettings');
      stream['security'] = 'none';
    }
  }

  Map<String, dynamic> _streamForSwitch() {
    final value = _outbound['streamSettings'];
    if (value is Map<String, dynamic>) {
      return value;
    }
    final stream = <String, dynamic>{};
    _outbound['streamSettings'] = stream;
    return stream;
  }

  bool _validHysteriaStream() {
    final stream = _outbound['streamSettings'];
    if (stream is! Map<String, dynamic> ||
        _string(stream, 'network') != 'hysteria' ||
        _string(stream, 'security') != 'tls') {
      return false;
    }
    final settings = stream['hysteriaSettings'];
    return settings is Map<String, dynamic> &&
        settings['version'] == 2 &&
        _validString(settings, 'auth');
  }

  void _rememberInitialValues() {
    _initial
      ..clear()
      ..addAll({
        'name': name,
        'tag': tag,
        'address': address,
        'port': port,
        'vlessId': vlessId,
        'vlessEncryption': vlessEncryption,
        'vlessFlow': vlessFlow,
        'vmessId': vmessId,
        'vmessSecurityName': vmessSecurityName,
        'shadowsocksMethodName': shadowsocksMethodName,
        'shadowsocksPassword': shadowsocksPassword,
        'trojanPassword': trojanPassword,
        'socksUser': socksUser,
        'socksPass': socksPass,
        'hysteriaAuth': hysteriaAuth,
        'wsPath': wsPath,
        'wsHost': wsHost,
        'grpcAuthority': grpcAuthority,
        'grpcServiceName': grpcServiceName,
        'grpcMultiMode': grpcMultiMode,
        'httpupgradeHost': httpupgradeHost,
        'httpupgradePath': httpupgradePath,
        'xhttpHost': xhttpHost,
        'xhttpPath': xhttpPath,
        'xhttpMode': xhttpMode,
        'serverName': serverName,
        'alpnText': alpnText,
        'fingerprint': fingerprint,
        'pinnedPeerCertSha256': pinnedPeerCertSha256,
        'verifyPeerCertByName': verifyPeerCertByName,
        'echConfigList': echConfigList,
        'realityPassword': realityPassword,
        'shortId': shortId,
        'mldsa65Verify': mldsa65Verify,
        'spiderX': spiderX,
      });
  }

  void _resetForm() {
    name = '';
    tag = '';
    protocolName = '';
    address = '';
    port = '';
    vlessId = '';
    vlessEncryption = '';
    vlessFlow = '';
    vmessId = '';
    vmessSecurityName = '';
    shadowsocksMethodName = '';
    shadowsocksPassword = '';
    trojanPassword = '';
    socksUser = '';
    socksPass = '';
    hysteriaAuth = '';
    networkName = '';
    wsPath = '';
    wsHost = '';
    grpcAuthority = '';
    grpcServiceName = '';
    grpcMultiMode = false;
    httpupgradeHost = '';
    httpupgradePath = '';
    xhttpHost = '';
    xhttpPath = '';
    xhttpMode = '';
    securityName = '';
    serverName = '';
    alpnText = '';
    fingerprint = '';
    pinnedPeerCertSha256 = '';
    verifyPeerCertByName = '';
    echConfigList = '';
    realityPassword = '';
    shortId = '';
    mldsa65Verify = '';
    spiderX = '';
  }

  bool _changed(String key, Object? current) => _initial[key] != current;

  void _patch(
    Map<String, dynamic> target,
    String key,
    Object? current,
    String initialKey, {
    Object? value,
  }) {
    if (_changed(initialKey, current)) {
      target[key] = value ?? current;
    }
  }
}

Map<String, dynamic> _newProtocolSettings(XrayOutboundProtocol protocol) =>
    switch (protocol) {
      XrayOutboundProtocol.vless => <String, dynamic>{'encryption': 'none'},
      XrayOutboundProtocol.vmess => <String, dynamic>{'security': 'auto'},
      XrayOutboundProtocol.shadowsocks => <String, dynamic>{
        'method': ShadowsocksMethod.aes256gcm.name,
      },
      XrayOutboundProtocol.hysteria => <String, dynamic>{'version': 2},
      _ => <String, dynamic>{},
    };

String _string(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value : '';
}

String _port(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is int ? '$value' : '';
}

List<String> _stringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is List<dynamic> ? value.cast<String>() : const [];
}

bool _validString(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == null || value is String;
}

bool _validStrings(Map<String, dynamic> map, List<String> keys) =>
    keys.every((key) => _validString(map, key));

bool _validPort(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == null || value is int;
}

bool _validBool(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == null || value is bool;
}

bool _validStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == null ||
      value is List<dynamic> && value.every((item) => item is String);
}

Map<String, dynamic>? _optionalObject(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) {
    return <String, dynamic>{};
  }
  return value is Map<String, dynamic> ? value : null;
}

Map<String, dynamic> _objectForPatch(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  final object = <String, dynamic>{};
  map[key] = object;
  return object;
}

String? _networkSettingsKey(String network) => switch (network) {
  'raw' => 'rawSettings',
  'ws' => 'wsSettings',
  'grpc' => 'grpcSettings',
  'httpupgrade' => 'httpupgradeSettings',
  'xhttp' => 'xhttpSettings',
  'hysteria' => 'hysteriaSettings',
  _ => null,
};

String? _securitySettingsKey(String security) => switch (security) {
  'tls' => 'tlsSettings',
  'reality' => 'realitySettings',
  _ => null,
};

void _removeActiveNetworkSettings(Map<String, dynamic> stream, String network) {
  final key = _networkSettingsKey(network);
  if (key != null) {
    stream.remove(key);
  }
}

void _removeActiveSecuritySettings(
  Map<String, dynamic> stream,
  String security,
) {
  final key = _securitySettingsKey(security);
  if (key != null) {
    stream.remove(key);
  }
}
