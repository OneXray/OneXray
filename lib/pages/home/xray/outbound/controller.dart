import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/home/xray/outbound/params.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/params.dart';
import 'package:onexray/pages/home/xray/raw_edit/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/setting/tun/network_interface/params.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_ping.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_validator.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/outbound/xhttp/state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/standard.dart';

class OutboundUIState {
  final OutboundState outboundState;
  final List<String> dialerProxies;
  final int version;

  const OutboundUIState({
    required this.outboundState,
    required this.dialerProxies,
    this.version = 0,
  });

  factory OutboundUIState.initial() => OutboundUIState(
        outboundState: OutboundState(),
        dialerProxies: const [],
      );

  OutboundUIState copyWith({
    OutboundState? outboundState,
    List<String>? dialerProxies,
    int? version,
  }) {
    return OutboundUIState(
      outboundState: outboundState ?? this.outboundState,
      dialerProxies: dialerProxies ?? this.dialerProxies,
      version: version ?? this.version,
    );
  }

  OutboundUIState bumped() => copyWith(version: version + 1);
}

class OutboundUIController extends Cubit<OutboundUIState> {
  final OutboundUIParams params;
  OutboundUIController(this.params) : super(OutboundUIState.initial()) {
    _initParams();
  }

  CoreConfigData? _outboundData;

  @override
  Future<void> close() {
    nameController.dispose();
    addressController.dispose();
    portController.dispose();
    vlessIdController.dispose();
    vlessEncryptionController.dispose();
    vlessReverseTagController.dispose();
    vmessIdController.dispose();
    shadowsocksPasswordController.dispose();
    trojanPasswordController.dispose();
    socksUserController.dispose();
    socksPassController.dispose();
    tagController.dispose();
    xhttpHostController.dispose();
    xhttpPathController.dispose();
    kcpHeaderDomainController.dispose();
    kcpSeedController.dispose();
    grpcAuthorityController.dispose();
    grpcServiceNameController.dispose();
    wsPathController.dispose();
    wsHostController.dispose();
    httpupgradeHostController.dispose();
    httpupgradePathController.dispose();

    hysteriaAuthController.dispose();
    hysteriaUpController.dispose();
    hysteriaDownController.dispose();
    hysteriaUdphopPortController.dispose();
    hysteriaUdphopIntervalController.dispose();

    serverNameController.dispose();
    pinnedPeerCertSha256Controller.dispose();
    verifyPeerCertByNameController.dispose();
    echConfigListController.dispose();
    passwordController.dispose();
    shortIdController.dispose();
    mldsa65VerifyController.dispose();
    spiderXController.dispose();
    muxConcurrencyController.dispose();
    muxXudpConcurrencyController.dispose();

    // dispose controller list
    for (final controller in rawPathControllers) {
      controller.dispose();
    }
    for (final controller in rawHostControllers) {
      controller.dispose();
    }

    return super.close();
  }

  void _initParams() {
    if (params.id != DBConstants.defaultId) {
      _queryOutbound();
    } else {
      _updateState(params.state);
    }
  }

  Future<void> _queryOutbound() async {
    final db = AppDatabase();
    final outbound = await db.coreConfigDao.searchRow(params.id);
    if (outbound != null) {
      _outboundData = outbound;
      final outboundState = OutboundState();
      outboundState.readFromDbData(outbound);
      _updateState(outboundState);
    }
  }

  void _updateState(OutboundState outboundState) {
    final dialerProxies = _fixDialerProxies(outboundState);
    _initInputs(outboundState);
    _initInput(outboundState);
    emit(state.copyWith(
      outboundState: outboundState,
      dialerProxies: dialerProxies,
      version: state.version + 1,
    ));
  }

  List<String> _fixDialerProxies(OutboundState outboundState) {
    final outboundTags = <String>[
      "",
      RoutingOutboundTag.direct.name,
      RoutingOutboundTag.fragment.name,
    ];
    params.outboundTags.clear();
    params.outboundTags.addAll(outboundTags);

    if (outboundState.tag.isNotEmpty) {
      if (params.outboundTags.contains(outboundState.tag)) {
        params.outboundTags.remove(outboundState.dialerProxy);
      }
    }
    if (outboundState.dialerProxy.isNotEmpty) {
      if (!params.outboundTags.contains(outboundState.dialerProxy)) {
        outboundState.dialerProxy = "";
      }
    }

    return List<String>.from(params.outboundTags);
  }

  void _initInputs(OutboundState outboundState) {
    final rawPathCtrls = outboundState.rawPath.map(
      (e) => TextEditingController(text: e),
    );
    rawPathControllers.clear();
    rawPathControllers.addAll(rawPathCtrls);

    final rawHostCtrls = outboundState.rawHost.map(
      (e) => TextEditingController(text: e),
    );
    rawHostControllers.clear();
    rawHostControllers.addAll(rawHostCtrls);
  }

  void _initInput(OutboundState outboundState) {
    nameController.text = outboundState.name;

    addressController.text = outboundState.address;
    portController.text = outboundState.port;

    vlessIdController.text = outboundState.vlessId;
    vlessEncryptionController.text = outboundState.vlessEncryption;
    vlessReverseTagController.text = outboundState.vlessReverseTag;
    vmessIdController.text = outboundState.vmessId;
    shadowsocksPasswordController.text = outboundState.shadowsocksPassword;
    trojanPasswordController.text = outboundState.trojanPassword;
    socksUserController.text = outboundState.socksUser;
    socksPassController.text = outboundState.socksPass;

    tagController.text = outboundState.tag;

    xhttpHostController.text = outboundState.xhttpHost;
    xhttpPathController.text = outboundState.xhttpPath;

    kcpHeaderDomainController.text = outboundState.kcpHeaderDomain;
    kcpSeedController.text = outboundState.kcpSeed;

    grpcAuthorityController.text = outboundState.grpcAuthority;
    grpcServiceNameController.text = outboundState.grpcServiceName;

    wsPathController.text = outboundState.wsPath;
    wsHostController.text = outboundState.wsHost;

    httpupgradeHostController.text = outboundState.httpupgradeHost;
    httpupgradePathController.text = outboundState.httpupgradePath;

    hysteriaAuthController.text = outboundState.hysteriaAuth;
    hysteriaUpController.text = outboundState.hysteriaUp;
    hysteriaDownController.text = outboundState.hysteriaDown;
    hysteriaUdphopPortController.text = outboundState.hysteriaUdphopPort;
    hysteriaUdphopIntervalController.text = outboundState.hysteriaUdphopInterval;

    serverNameController.text = outboundState.serverName;
    pinnedPeerCertSha256Controller.text = outboundState.pinnedPeerCertSha256;
    verifyPeerCertByNameController.text = outboundState.verifyPeerCertByName;
    echConfigListController.text = outboundState.echConfigList;
    passwordController.text = outboundState.password;
    shortIdController.text = outboundState.shortId;
    mldsa65VerifyController.text = outboundState.mldsa65Verify;
    spiderXController.text = outboundState.spiderX;

    muxConcurrencyController.text = outboundState.muxConcurrency;
    muxXudpConcurrencyController.text = outboundState.muxXudpConcurrency;
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    final xrayJson = XrayJsonStandard.standard;
    xrayJson.outbounds = [state.outboundState.xrayJson];
    final jsonMap = xrayJson.toJson();
    final text = JsonTool.encoderForFile.convert(jsonMap);
    final params = XrayRawEditParams(text);
    final newText = await context.push<String>(
      RouterPath.xrayRawEdit,
      extra: params,
    );
    if (newText != null) {
      final newOutboundState = OutboundState();
      if (newOutboundState.readFromText(newText)) {
        _updateState(newOutboundState);
      }
    }
  }

  final nameController = TextEditingController();

  void updateProtocol(XrayOutboundProtocol value) {
    state.outboundState.protocol = value;
    emit(state.bumped());
  }

  final addressController = TextEditingController();
  final portController = TextEditingController();

  final vlessIdController = TextEditingController();
  final vlessEncryptionController = TextEditingController();
  final vlessReverseTagController = TextEditingController();

  void updateVlessFlow(VLESSFlow value) {
    state.outboundState.vlessFlow = value;
    emit(state.bumped());
  }

  final vmessIdController = TextEditingController();

  void updateVmessSecurity(VMessSecurity value) {
    state.outboundState.vmessSecurity = value;
    emit(state.bumped());
  }

  void updateShadowsocksMethod(ShadowsocksMethod value) {
    state.outboundState.shadowsocksMethod = value;
    emit(state.bumped());
  }

  final shadowsocksPasswordController = TextEditingController();

  void updateShadowsocksUot(bool value) {
    state.outboundState.shadowsocksUot = value;
    emit(state.bumped());
  }

  void updateShadowsocksUotVersion(ShadowsocksUoTVersion value) {
    state.outboundState.shadowsocksUotVersion = value;
    emit(state.bumped());
  }

  final trojanPasswordController = TextEditingController();

  final socksUserController = TextEditingController();
  final socksPassController = TextEditingController();

  final tagController = TextEditingController();

  void updateNetwork(StreamSettingsNetwork value) {
    state.outboundState.network = value;
    emit(state.bumped());
  }

  void updateRawHeaderType(RawHeaderType value) {
    state.outboundState.rawHeaderType = value;
    emit(state.bumped());
  }

  final rawPathControllers = <TextEditingController>[];

  void appendRawPath() {
    rawPathControllers.add(TextEditingController());
    state.outboundState.rawPath.add("");
    emit(state.bumped());
  }

  void deleteRawPath(BuildContext context, int index) {
    final controller = rawPathControllers.removeAt(index);
    controller.dispose();
    state.outboundState.rawPath.removeAt(index);
    emit(state.bumped());
  }

  final rawHostControllers = <TextEditingController>[];

  void appendRawHost() {
    rawHostControllers.add(TextEditingController());
    state.outboundState.rawHost.add("");
    emit(state.bumped());
  }

  void deleteRawHost(BuildContext context, int index) {
    final controller = rawHostControllers.removeAt(index);
    controller.dispose();
    state.outboundState.rawHost.removeAt(index);
    emit(state.bumped());
  }

  void updateKcpHeaderType(KcpHeaderType value) {
    state.outboundState.kcpHeaderType = value;
    emit(state.bumped());
  }

  final wsPathController = TextEditingController();
  final wsHostController = TextEditingController();

  final kcpHeaderDomainController = TextEditingController();
  final kcpSeedController = TextEditingController();

  final grpcAuthorityController = TextEditingController();
  final grpcServiceNameController = TextEditingController();

  void updateGrpcMultiMode(bool value) {
    state.outboundState.grpcMultiMode = value;
    emit(state.bumped());
  }

  final httpupgradeHostController = TextEditingController();
  final httpupgradePathController = TextEditingController();

  final xhttpHostController = TextEditingController();
  final xhttpPathController = TextEditingController();

  void updateXhttpMode(XhttpMode value) {
    state.outboundState.xhttpMode = value;
    emit(state.bumped());
  }

  Future<void> editXhttpExtra(BuildContext context) async {
    final params = OutboundXhttpParams(
      state.outboundState.xhttpMode,
      state.outboundState.xhttpExtra,
    );
    final xhttpExtra = await context.push<XhttpExtraState>(
      RouterPath.outboundXhttp,
      extra: params,
    );
    if (xhttpExtra != null) {
      state.outboundState.xhttpExtra = xhttpExtra;
      emit(state.bumped());
    }
  }

  final hysteriaAuthController = TextEditingController();
  final hysteriaUpController = TextEditingController();
  final hysteriaDownController = TextEditingController();
  final hysteriaUdphopPortController = TextEditingController();
  final hysteriaUdphopIntervalController = TextEditingController();

  Future<void> editFinalMask(BuildContext context) async {
    final finalMask = state.outboundState.finalMask;
    final text = JsonTool.encoderForFile.convert(finalMask);
    final params = XrayRawEditParams(text);
    final newText = await context.push<String>(
      RouterPath.xrayRawEdit,
      extra: params,
    );
    if (newText != null) {
      state.outboundState.finalMask =
          JsonTool.decoder.convert(newText) as Map<String, dynamic>;
      emit(state.bumped());
    }
  }

  void updateSecurity(StreamSettingsSecurity value) {
    state.outboundState.security = value;
    emit(state.bumped());
  }

  final serverNameController = TextEditingController();

  void updateFingerprint(StreamSettingsSecurityFingerprint value) {
    state.outboundState.fingerprint = value;
    emit(state.bumped());
  }

  void updateAlpn(bool selected, StreamSettingsSecurityALPN value) {
    if (selected) {
      state.outboundState.alpn.add(value);
    } else {
      state.outboundState.alpn.remove(value);
    }
    emit(state.bumped());
  }

  final pinnedPeerCertSha256Controller = TextEditingController();
  final verifyPeerCertByNameController = TextEditingController();

  final echConfigListController = TextEditingController();
  void updateEchForceQuery(StreamSettingsEchForceQuery value) {
    state.outboundState.echForceQuery = value;
    emit(state.bumped());
  }

  final passwordController = TextEditingController();
  final shortIdController = TextEditingController();
  final mldsa65VerifyController = TextEditingController();
  final spiderXController = TextEditingController();

  void updateMuxEnabled(bool value) {
    state.outboundState.muxEnabled = value;
    emit(state.bumped());
  }

  final muxConcurrencyController = TextEditingController();
  final muxXudpConcurrencyController = TextEditingController();

  void updateMuxXudpProxyUDP443(MuxXudpProxyUDP443 value) {
    state.outboundState.muxXudpProxyUDP443 = value;
    emit(state.bumped());
  }

  void updateTcpFastOpen(bool value) {
    state.outboundState.tcpFastOpen = value;
    emit(state.bumped());
  }

  void updateDialerProxy(String value) {
    state.outboundState.dialerProxy = value;
    emit(state.bumped());
  }

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(state.outboundState.interface);
    final networkInterface = await context.push<String>(
      RouterPath.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.outboundState.interface = networkInterface;
      emit(state.bumped());
    }
  }

  void updateTcpMptcp(bool value) {
    state.outboundState.tcpMptcp = value;
    emit(state.bumped());
  }

  Future<void> realPing(BuildContext context) async {
    _mergeInputToState(state.outboundState);
    emit(state.bumped());
    final checked = await _validate(context);
    if (checked) {
      final eventBus = AppEventBus.instance;
      eventBus.updatePinging(true);
      final pingState = PingState();
      await pingState.readFromPreferences();
      final res = await state.outboundState.ping(pingState);
      eventBus.updatePinging(false);
      if (context.mounted) {
        await ContextAlert.showPingResultDialog(context, res);
      }
    }
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(state.outboundState);
    emit(state.bumped());
    final checked = await _validate(context);
    if (checked) {
      await _updateDb();
      if (context.mounted) {
        context.pop();
      }
    }
  }

  Future<void> _updateDb() async {
    if (params.id == DBConstants.defaultId) {
      await state.outboundState.insertToDb();
    } else {
      if (_outboundData != null) {
        await state.outboundState.updateToDb(_outboundData!);
      }
    }
  }

  void _mergeInputToState(OutboundState outboundState) {
    _mergeInputs(outboundState);
    _mergeInput(outboundState);

    outboundState.removeWhitespace();
  }

  void _mergeInputs(OutboundState outboundState) {
    outboundState.rawPath = rawPathControllers.map((c) => c.text).toList();
    outboundState.rawHost = rawHostControllers.map((c) => c.text).toList();
  }

  void _mergeInput(OutboundState outboundState) {
    outboundState.name = nameController.text;

    outboundState.address = addressController.text;
    outboundState.port = portController.text;

    outboundState.vlessId = vlessIdController.text;
    outboundState.vlessEncryption = vlessEncryptionController.text;
    outboundState.vlessReverseTag = vlessReverseTagController.text;
    outboundState.vmessId = vmessIdController.text;
    outboundState.shadowsocksPassword = shadowsocksPasswordController.text;
    outboundState.trojanPassword = trojanPasswordController.text;
    outboundState.socksUser = socksUserController.text;
    outboundState.socksPass = socksPassController.text;

    outboundState.tag = tagController.text;

    outboundState.xhttpHost = xhttpHostController.text;
    outboundState.xhttpPath = xhttpPathController.text;

    outboundState.kcpHeaderDomain = kcpHeaderDomainController.text;
    outboundState.kcpSeed = kcpSeedController.text;

    outboundState.grpcAuthority = grpcAuthorityController.text;
    outboundState.grpcServiceName = grpcServiceNameController.text;

    outboundState.wsPath = wsPathController.text;
    outboundState.wsHost = wsHostController.text;

    outboundState.httpupgradeHost = httpupgradeHostController.text;
    outboundState.httpupgradePath = httpupgradePathController.text;

    outboundState.hysteriaAuth = hysteriaAuthController.text;
    outboundState.hysteriaUp = hysteriaUpController.text;
    outboundState.hysteriaDown = hysteriaDownController.text;
    outboundState.hysteriaUdphopPort = hysteriaUdphopPortController.text;
    outboundState.hysteriaUdphopInterval = hysteriaUdphopIntervalController.text;

    outboundState.serverName = serverNameController.text;
    outboundState.pinnedPeerCertSha256 = pinnedPeerCertSha256Controller.text;
    outboundState.verifyPeerCertByName = verifyPeerCertByNameController.text;
    outboundState.echConfigList = echConfigListController.text;
    outboundState.password = passwordController.text;
    outboundState.shortId = shortIdController.text;
    outboundState.mldsa65Verify = mldsa65VerifyController.text;
    outboundState.spiderX = spiderXController.text;

    outboundState.muxConcurrency = muxConcurrencyController.text;
    outboundState.muxXudpConcurrency = muxXudpConcurrencyController.text;
  }

  Future<bool> _validate(BuildContext context) async {
    final tuple = await state.outboundState.validate();
    if (!context.mounted) {
      return false;
    }
    if (!tuple.item1) {
      ygLogger("Outbound validate failed: ${tuple.item2}");
      ContextAlert.showToast(context, tuple.item2);
    }
    return tuple.item1;
  }
}
