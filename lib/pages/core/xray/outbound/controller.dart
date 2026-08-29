import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_ping.dart';
import 'package:onexray/service/xray/outbound/state_validator.dart';

class OutboundUIPageState {
  final OutboundState outboundState;
  final bool loaded;

  const OutboundUIPageState({required this.outboundState, this.loaded = false});

  factory OutboundUIPageState.initial() =>
      OutboundUIPageState(outboundState: OutboundState());

  OutboundUIPageState copyWith({OutboundState? outboundState, bool? loaded}) {
    return OutboundUIPageState(
      outboundState: outboundState ?? this.outboundState,
      loaded: loaded ?? this.loaded,
    );
  }
}

class OutboundUIController extends PageCubit<OutboundUIPageState> {
  final OutboundUIParams params;

  OutboundUIController(this.params) : super(OutboundUIPageState.initial()) {
    _initParams();
  }

  CoreConfigData? _outboundData;

  final addressController = TextEditingController();
  final portController = TextEditingController();
  final vlessIdController = TextEditingController();
  final vlessEncryptionController = TextEditingController();
  final vlessFlowController = TextEditingController();
  final vmessIdController = TextEditingController();
  final shadowsocksPasswordController = TextEditingController();
  final trojanPasswordController = TextEditingController();
  final socksUserController = TextEditingController();
  final socksPassController = TextEditingController();
  final tagController = TextEditingController();
  final xhttpHostController = TextEditingController();
  final xhttpPathController = TextEditingController();
  final xhttpModeController = TextEditingController();
  final grpcAuthorityController = TextEditingController();
  final grpcServiceNameController = TextEditingController();
  final wsPathController = TextEditingController();
  final wsHostController = TextEditingController();
  final httpupgradeHostController = TextEditingController();
  final httpupgradePathController = TextEditingController();
  final hysteriaAuthController = TextEditingController();
  final serverNameController = TextEditingController();
  final fingerprintController = TextEditingController();
  final pinnedPeerCertSha256Controller = TextEditingController();
  final verifyPeerCertByNameController = TextEditingController();
  final echConfigListController = TextEditingController();
  final realityPasswordController = TextEditingController();
  final shortIdController = TextEditingController();
  final mldsa65VerifyController = TextEditingController();
  final spiderXController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    for (final controller in [
      addressController,
      portController,
      vlessIdController,
      vlessEncryptionController,
      vlessFlowController,
      vmessIdController,
      shadowsocksPasswordController,
      trojanPasswordController,
      socksUserController,
      socksPassController,
      tagController,
      xhttpHostController,
      xhttpPathController,
      xhttpModeController,
      grpcAuthorityController,
      grpcServiceNameController,
      wsPathController,
      wsHostController,
      httpupgradeHostController,
      httpupgradePathController,
      hysteriaAuthController,
      serverNameController,
      fingerprintController,
      pinnedPeerCertSha256Controller,
      verifyPeerCertByNameController,
      echConfigListController,
      realityPasswordController,
      shortIdController,
      mldsa65VerifyController,
      spiderXController,
    ]) {
      controller.dispose();
    }
  }

  void _initParams() {
    if (params.id != DBConstants.defaultId) {
      _queryOutbound();
      return;
    }
    final outbound = params.outbound.isEmpty
        ? newOutboundMap()
        : params.outbound;
    _updateState(OutboundState(outbound));
  }

  Future<void> _queryOutbound() async {
    final outbound = await AppDatabase().coreConfigDao.searchRow(params.id);
    if (!isPageActive || outbound == null) {
      return;
    }
    try {
      final outboundState = OutboundState(readOutboundFromDbData(outbound));
      _outboundData = outbound;
      _updateState(outboundState);
    } on FormatException catch (error) {
      ygLogger('Read outbound failed: ${outbound.id}, $error');
    }
  }

  void _updateState(OutboundState outboundState) {
    if (params.fixedTag.isNotEmpty) {
      outboundState.tag = params.fixedTag;
    }
    _initInputs(outboundState);
    emit(state.copyWith(outboundState: outboundState, loaded: true));
  }

  void _initInputs(OutboundState outboundState) {
    addressController.text = outboundState.address;
    portController.text = outboundState.port;
    vlessIdController.text = outboundState.vlessId;
    vlessEncryptionController.text = outboundState.vlessEncryption;
    vlessFlowController.text = outboundState.vlessFlow;
    vmessIdController.text = outboundState.vmessId;
    shadowsocksPasswordController.text = outboundState.shadowsocksPassword;
    trojanPasswordController.text = outboundState.trojanPassword;
    socksUserController.text = outboundState.socksUser;
    socksPassController.text = outboundState.socksPass;
    tagController.text = outboundState.tag;
    xhttpHostController.text = outboundState.xhttpHost;
    xhttpPathController.text = outboundState.xhttpPath;
    xhttpModeController.text = outboundState.xhttpMode;
    grpcAuthorityController.text = outboundState.grpcAuthority;
    grpcServiceNameController.text = outboundState.grpcServiceName;
    wsPathController.text = outboundState.wsPath;
    wsHostController.text = outboundState.wsHost;
    httpupgradeHostController.text = outboundState.httpupgradeHost;
    httpupgradePathController.text = outboundState.httpupgradePath;
    hysteriaAuthController.text = outboundState.hysteriaAuth;
    serverNameController.text = outboundState.serverName;
    fingerprintController.text = outboundState.fingerprint;
    pinnedPeerCertSha256Controller.text = outboundState.pinnedPeerCertSha256;
    verifyPeerCertByNameController.text = outboundState.verifyPeerCertByName;
    echConfigListController.text = outboundState.echConfigList;
    realityPasswordController.text = outboundState.realityPassword;
    shortIdController.text = outboundState.shortId;
    mldsa65VerifyController.text = outboundState.mldsa65Verify;
    spiderXController.text = outboundState.spiderX;
  }

  Future<void> gotoRawEdit(BuildContext context) async {
    if (!_ensureLoaded(context)) {
      return;
    }
    final outbound = _outboundFromInputs();
    final rawParams = XrayRawEditParams(
      AppLocalizations.of(context)!.outboundPageTitle,
      encodeSingleOutbound(outbound),
      validator: (text) {
        try {
          decodeSingleOutbound(text);
          return null;
        } on FormatException catch (error) {
          return error.message;
        }
      },
    );
    final newText = await context.pushScoped<String>(
      AppSecondaryDestination.xrayRawEdit,
      extra: rawParams,
    );
    if (newText == null || !context.mounted) {
      return;
    }
    try {
      _updateState(OutboundState(decodeSingleOutbound(newText)));
    } on FormatException {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.validationJsonInvalid,
      );
    }
  }

  void updateProtocol(XrayOutboundProtocol value) {
    _readInputsIntoState(state.outboundState);
    state.outboundState.changeProtocol(value);
    _updateState(state.outboundState);
  }

  void updateVmessSecurity(VMessSecurity value) {
    state.outboundState.selectVmessSecurity(value);
    emit(state.copyWith());
  }

  void updateShadowsocksMethod(ShadowsocksMethod value) {
    state.outboundState.selectShadowsocksMethod(value);
    emit(state.copyWith());
  }

  void updateNetwork(StreamSettingsNetwork value) {
    _readInputsIntoState(state.outboundState);
    state.outboundState.changeNetwork(value);
    _updateState(state.outboundState);
  }

  void updateGrpcMultiMode(bool value) {
    state.outboundState.grpcMultiMode = value;
    emit(state.copyWith());
  }

  void updateSecurity(StreamSettingsSecurity value) {
    _readInputsIntoState(state.outboundState);
    state.outboundState.changeSecurity(value);
    _updateState(state.outboundState);
  }

  Future<void> realPing(BuildContext context) async {
    if (!_ensureLoaded(context)) {
      return;
    }
    final outbound = _outboundFromInputs();
    final eventBus = AppEventBus.instance;
    eventBus.updatePinging(true);
    try {
      final pingState = PingState();
      await pingState.readFromPreferences();
      final result = await pingOutbound(
        outbound,
        pingState,
        fallbackDelay: PingDelayConstants.error,
      );
      if (context.mounted) {
        await ContextAlert.showPingResultDialog(context, result);
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ContextAlert.showToast(context, error.message);
      }
    } finally {
      eventBus.updatePinging(false);
    }
  }

  Future<void> save(BuildContext context) async {
    if (!_ensureLoaded(context)) {
      return;
    }
    final outbound = _outboundFromInputs();
    if (!await _validate(context, outbound)) {
      return;
    }
    if (params.saveToDb) {
      await _updateDb(outbound);
    }
    if (!context.mounted) {
      return;
    }
    if (params.saveToDb) {
      context.pop();
    } else {
      context.pop<Map<String, dynamic>>(outbound);
    }
  }

  Future<void> _updateDb(Map<String, dynamic> outbound) async {
    if (params.id == DBConstants.defaultId) {
      final id = await insertOutboundToDb(outbound);
      PingService().schedulePingConfigIds([id]);
      return;
    }
    final row = _outboundData;
    if (row != null) {
      await updateOutboundToDb(outbound, row);
    }
  }

  bool _ensureLoaded(BuildContext context) {
    if (params.id == DBConstants.defaultId || _outboundData != null) {
      return true;
    }
    ContextAlert.showToast(
      context,
      AppLocalizations.of(context)!.vpnOutboundInvalid,
    );
    return false;
  }

  Map<String, dynamic> _outboundFromInputs() {
    _readInputsIntoState(state.outboundState);
    final outbound = state.outboundState.materialize();
    emit(state.copyWith());
    return outbound;
  }

  void _readInputsIntoState(OutboundState outboundState) {
    outboundState.address = addressController.text;
    outboundState.port = portController.text;
    outboundState.vlessId = vlessIdController.text;
    outboundState.vlessEncryption = vlessEncryptionController.text;
    outboundState.vlessFlow = vlessFlowController.text;
    outboundState.vmessId = vmessIdController.text;
    outboundState.shadowsocksPassword = shadowsocksPasswordController.text;
    outboundState.trojanPassword = trojanPasswordController.text;
    outboundState.socksUser = socksUserController.text;
    outboundState.socksPass = socksPassController.text;
    outboundState.tag = params.fixedTag.isEmpty
        ? tagController.text
        : params.fixedTag;
    outboundState.xhttpHost = xhttpHostController.text;
    outboundState.xhttpPath = xhttpPathController.text;
    outboundState.xhttpMode = xhttpModeController.text;
    outboundState.grpcAuthority = grpcAuthorityController.text;
    outboundState.grpcServiceName = grpcServiceNameController.text;
    outboundState.wsPath = wsPathController.text;
    outboundState.wsHost = wsHostController.text;
    outboundState.httpupgradeHost = httpupgradeHostController.text;
    outboundState.httpupgradePath = httpupgradePathController.text;
    outboundState.hysteriaAuth = hysteriaAuthController.text;
    outboundState.serverName = serverNameController.text;
    outboundState.fingerprint = fingerprintController.text;
    outboundState.pinnedPeerCertSha256 = pinnedPeerCertSha256Controller.text;
    outboundState.verifyPeerCertByName = verifyPeerCertByNameController.text;
    outboundState.echConfigList = echConfigListController.text;
    outboundState.realityPassword = realityPasswordController.text;
    outboundState.shortId = shortIdController.text;
    outboundState.mldsa65Verify = mldsa65VerifyController.text;
    outboundState.spiderX = spiderXController.text;
  }

  Future<bool> _validate(
    BuildContext context,
    Map<String, dynamic> outbound,
  ) async {
    final result = await validateOutbound(outbound);
    if (!context.mounted) {
      return false;
    }
    if (!result.item1) {
      ygLogger('Outbound validate failed: ${result.item2}');
      ContextAlert.showToast(context, result.item2);
    }
    return result.item1;
  }
}
