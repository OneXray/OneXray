import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/localizations/service.dart';

enum AdditionalInboundType { socks, http, dokodemoDoor }

enum DokodemoDoorNetwork {
  tcp('tcp'),
  udp('udp'),
  tcpUdp('tcp,udp');

  const DokodemoDoorNetwork(this.name);

  final String name;

  static DokodemoDoorNetwork fromString(String? value) {
    for (final network in values) {
      if (network.name == value) {
        return network;
      }
    }
    return tcp;
  }
}

abstract class AdditionalInboundState {
  static const allInterfacesListen = '';
  static final localListen = NetConstants.proxyHost;
  static final listenValues = <String>[allInterfacesListen, localListen];

  AdditionalInboundState({
    required this.listen,
    required this.port,
    required this.tag,
  });

  String listen;
  String port;
  String tag;

  AdditionalInboundType get type;

  XrayInbound get xrayJson;

  AdditionalInboundState copy();

  void removeWhitespace() {
    listen = listen.removeWhitespace;
    port = port.removeWhitespace;
    tag = tag.removeWhitespace;
  }

  String? validate({
    Set<String> unavailableTags = const {},
    Set<int> unavailablePorts = const {},
  }) {
    final l10n = appLocalizationsNoContext();
    if (tag.isEmpty) {
      return l10n.validationTagRequired;
    }
    if (unavailableTags.contains(tag)) {
      return l10n.validationTagUnique;
    }

    final portNumber = int.tryParse(port);
    if (portNumber == null || portNumber < 1 || portNumber > 65535) {
      return l10n.validationPortInvalid;
    }
    if (unavailablePorts.contains(portNumber)) {
      return l10n.validationPortDuplicate;
    }
    return null;
  }

  static AdditionalInboundState? fromXrayInbound(XrayInbound inbound) {
    if (inbound.tag == null || inbound.tag!.isEmpty) {
      return null;
    }
    return switch (inbound.protocol) {
      'socks' => InboundSocksState.fromXrayInbound(inbound),
      'http' => InboundHttpState.fromXrayInbound(inbound),
      'dokodemo-door' => InboundDokodemoDoorState.fromXrayInbound(inbound),
      _ => null,
    };
  }

  static String normalizeListen(String? value, {bool allowAll = true}) {
    final normalized = (value ?? '').removeWhitespace.toLowerCase();
    if (allowAll &&
        (normalized.isEmpty ||
            normalized == '0.0.0.0' ||
            normalized == '::' ||
            normalized == '[::]')) {
      return allInterfacesListen;
    }
    if (normalized == localListen ||
        normalized == 'localhost' ||
        normalized == '::1' ||
        normalized == '[::1]') {
      return localListen;
    }
    return localListen;
  }

  XrayInbound baseXrayJson(String protocol) {
    final inbound = XrayInboundStandard.standard;
    if (listen.isNotEmpty) {
      inbound.listen = listen;
    }
    inbound.port = port;
    inbound.protocol = protocol;
    inbound.tag = tag;
    return inbound;
  }
}

abstract class AuthenticatedAdditionalInboundState
    extends AdditionalInboundState {
  AuthenticatedAdditionalInboundState({
    required super.listen,
    required super.port,
    required super.tag,
    required this.user,
    required this.pass,
  });

  String user;
  String pass;

  bool get hasAnyCredentials => user.isNotEmpty || pass.isNotEmpty;

  bool get hasCompleteCredentials => user.isNotEmpty && pass.isNotEmpty;

  @override
  String? validate({
    Set<String> unavailableTags = const {},
    Set<int> unavailablePorts = const {},
  }) {
    final commonError = super.validate(
      unavailableTags: unavailableTags,
      unavailablePorts: unavailablePorts,
    );
    if (commonError != null) {
      return commonError;
    }
    if ((hasAnyCredentials && !hasCompleteCredentials) ||
        (listen == AdditionalInboundState.allInterfacesListen &&
            !hasCompleteCredentials)) {
      return appLocalizationsNoContext().validationInboundCredentialsRequired;
    }
    return null;
  }

  List<XrayInboundAccount>? get users => hasCompleteCredentials
      ? <XrayInboundAccount>[XrayInboundAccount(user, pass)]
      : null;

  void readUsers(List<XrayInboundAccount>? users) {
    if (users == null || users.isEmpty) {
      return;
    }
    user = users.first.user ?? '';
    pass = users.first.pass ?? '';
  }
}

class InboundSocksState extends AuthenticatedAdditionalInboundState {
  InboundSocksState({
    super.listen = '127.0.0.1',
    super.port = '11024',
    super.tag = 'socksIn1',
    super.user = '',
    super.pass = '',
  });

  final bool udp = true;

  @override
  AdditionalInboundType get type => AdditionalInboundType.socks;

  factory InboundSocksState.fromXrayInbound(XrayInbound inbound) {
    final state = InboundSocksState(
      listen: AdditionalInboundState.normalizeListen(inbound.listen),
      port: inbound.port ?? '11024',
      tag: inbound.tag ?? 'socksIn1',
    );
    final settings = inbound.settings;
    if (settings != null) {
      state.readUsers(XrayInboundSocksSettings.fromJson(settings).users);
    }
    return state;
  }

  @override
  InboundSocksState copy() => InboundSocksState(
    listen: listen,
    port: port,
    tag: tag,
    user: user,
    pass: pass,
  );

  @override
  XrayInbound get xrayJson {
    final inbound = baseXrayJson('socks');
    inbound.settings = XrayInboundSocksSettings(
      hasCompleteCredentials ? 'password' : 'noauth',
      udp,
      users,
    ).toJson();
    return inbound;
  }
}

class InboundHttpState extends AuthenticatedAdditionalInboundState {
  InboundHttpState({
    super.listen = '127.0.0.1',
    super.port = '11025',
    super.tag = 'httpIn1',
    super.user = '',
    super.pass = '',
  });

  @override
  AdditionalInboundType get type => AdditionalInboundType.http;

  factory InboundHttpState.fromXrayInbound(XrayInbound inbound) {
    final state = InboundHttpState(
      listen: AdditionalInboundState.normalizeListen(inbound.listen),
      port: inbound.port ?? '11025',
      tag: inbound.tag ?? 'httpIn1',
    );
    final settings = inbound.settings;
    if (settings != null) {
      state.readUsers(XrayInboundHttpSettings.fromJson(settings).users);
    }
    return state;
  }

  @override
  InboundHttpState copy() => InboundHttpState(
    listen: listen,
    port: port,
    tag: tag,
    user: user,
    pass: pass,
  );

  @override
  XrayInbound get xrayJson {
    final inbound = baseXrayJson('http');
    inbound.settings = XrayInboundHttpSettings(false, users).toJson();
    return inbound;
  }
}

class InboundDokodemoDoorState extends AdditionalInboundState {
  InboundDokodemoDoorState({
    super.listen = '127.0.0.1',
    super.port = '11026',
    super.tag = 'dokodemoDoor1',
    this.targetAddress = '127.0.0.1',
    this.targetPort = '',
    this.network = DokodemoDoorNetwork.tcp,
  });

  String targetAddress;
  String targetPort;
  DokodemoDoorNetwork network;

  @override
  AdditionalInboundType get type => AdditionalInboundType.dokodemoDoor;

  factory InboundDokodemoDoorState.fromXrayInbound(XrayInbound inbound) {
    final state = InboundDokodemoDoorState(
      listen: AdditionalInboundState.normalizeListen(
        inbound.listen,
        allowAll: false,
      ),
      port: inbound.port ?? '11026',
      tag: inbound.tag ?? 'dokodemoDoor1',
    );
    final settings = inbound.settings;
    if (settings != null) {
      final model = XrayInboundDokodemoDoorSettings.fromJson(settings);
      state.targetAddress = model.address ?? AdditionalInboundState.localListen;
      state.targetPort = model.port?.toString() ?? '';
      state.network = DokodemoDoorNetwork.fromString(model.network);
    }
    return state;
  }

  @override
  InboundDokodemoDoorState copy() => InboundDokodemoDoorState(
    listen: listen,
    port: port,
    tag: tag,
    targetAddress: targetAddress,
    targetPort: targetPort,
    network: network,
  );

  @override
  void removeWhitespace() {
    super.removeWhitespace();
    listen = AdditionalInboundState.localListen;
    targetAddress = targetAddress.removeWhitespace;
    targetPort = targetPort.removeWhitespace;
  }

  @override
  String? validate({
    Set<String> unavailableTags = const {},
    Set<int> unavailablePorts = const {},
  }) {
    final commonError = super.validate(
      unavailableTags: unavailableTags,
      unavailablePorts: unavailablePorts,
    );
    if (commonError != null) {
      return commonError;
    }
    if (targetAddress.isEmpty) {
      return appLocalizationsNoContext().validationInboundAddressRequired;
    }
    final targetPortNumber = int.tryParse(targetPort);
    if (targetPortNumber == null ||
        targetPortNumber < 1 ||
        targetPortNumber > 65535) {
      return appLocalizationsNoContext().validationPortInvalid;
    }
    return null;
  }

  @override
  XrayInbound get xrayJson {
    final inbound = baseXrayJson('dokodemo-door');
    inbound.settings = XrayInboundDokodemoDoorSettings(
      targetAddress,
      int.tryParse(targetPort),
      network.name,
    ).toJson();
    return inbound;
  }
}
