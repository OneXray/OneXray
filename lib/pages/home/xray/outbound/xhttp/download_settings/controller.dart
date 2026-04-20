import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/download_settings/params.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state_validator.dart';

class OutboundXhttpHeader {
  final key = TextEditingController();
  final value = TextEditingController();
}

class XhttpDownloadSettingsState {
  final XhttpDownloadState downloadState;
  final List<OutboundXhttpHeader> headers;
  final int version;

  const XhttpDownloadSettingsState({
    required this.downloadState,
    required this.headers,
    this.version = 0,
  });

  factory XhttpDownloadSettingsState.initial() => XhttpDownloadSettingsState(
        downloadState: XhttpDownloadState(),
        headers: const [],
      );

  XhttpDownloadSettingsState bumped() => XhttpDownloadSettingsState(
        downloadState: downloadState,
        headers: headers,
        version: version + 1,
      );
}

class XhttpDownloadSettingsController extends Cubit<XhttpDownloadSettingsState> {
  final XhttpDownloadSettingsParams params;
  XhttpDownloadSettingsController(this.params)
      : super(XhttpDownloadSettingsState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    xPaddingBytesController.dispose();
    scMaxEachPostBytesController.dispose();
    scMinPostsIntervalMsController.dispose();
    maxConcurrencyController.dispose();
    maxConnectionsController.dispose();
    cMaxReuseTimesController.dispose();
    hMaxReusableSecsController.dispose();
    hMaxRequestTimesController.dispose();
    hKeepAlivePeriodController.dispose();
    addressController.dispose();
    portController.dispose();
    xhttpHostController.dispose();
    xhttpPathController.dispose();
    serverNameController.dispose();
    pinnedPeerCertSha256Controller.dispose();
    verifyPeerCertByNameController.dispose();
    echConfigListController.dispose();
    passwordController.dispose();
    shortIdController.dispose();
    mldsa65VerifyController.dispose();
    spiderXController.dispose();

    for (final controller in state.headers) {
      controller.key.dispose();
      controller.value.dispose();
    }

    return super.close();
  }

  void _initParams() {
    final downloadState = params.state;
    final headers = <OutboundXhttpHeader>[];
    _initHeaders(downloadState, headers);
    _initInput(downloadState);
    emit(XhttpDownloadSettingsState(
      downloadState: downloadState,
      headers: headers,
      version: 1,
    ));
  }

  void _initHeaders(XhttpDownloadState downloadState, List<OutboundXhttpHeader> headers) {
    downloadState.headers.forEach((k, v) {
      final header = OutboundXhttpHeader();
      header.key.text = k;
      header.value.text = v;
      headers.add(header);
    });
  }

  void _initInput(XhttpDownloadState downloadState) {
    xPaddingBytesController.text = downloadState.xPaddingBytes;

    scMaxEachPostBytesController.text = downloadState.scMaxEachPostBytes;
    scMinPostsIntervalMsController.text = downloadState.scMinPostsIntervalMs;

    maxConcurrencyController.text = downloadState.maxConcurrency;
    maxConnectionsController.text = downloadState.maxConnections;
    cMaxReuseTimesController.text = downloadState.cMaxReuseTimes;
    hMaxReusableSecsController.text = downloadState.hMaxReusableSecs;
    hMaxRequestTimesController.text = downloadState.hMaxRequestTimes;
    hKeepAlivePeriodController.text = downloadState.hKeepAlivePeriod;

    addressController.text = downloadState.address;
    portController.text = downloadState.port;

    xhttpHostController.text = downloadState.xhttpHost;
    xhttpPathController.text = downloadState.xhttpPath;

    serverNameController.text = downloadState.serverName;
    pinnedPeerCertSha256Controller.text = downloadState.pinnedPeerCertSha256;
    verifyPeerCertByNameController.text = downloadState.verifyPeerCertByName;
    echConfigListController.text = downloadState.echConfigList;
    passwordController.text = downloadState.password;
    shortIdController.text = downloadState.shortId;
    mldsa65VerifyController.text = downloadState.mldsa65Verify;
    spiderXController.text = downloadState.spiderX;
  }

  void appendHeader() {
    state.headers.add(OutboundXhttpHeader());
    emit(state.bumped());
  }

  final xPaddingBytesController = TextEditingController();

  void updateNoGRPCHeader(bool value) {
    state.downloadState.noGRPCHeader = value;
    emit(state.bumped());
  }

  final scMaxEachPostBytesController = TextEditingController();
  final scMinPostsIntervalMsController = TextEditingController();

  final maxConcurrencyController = TextEditingController();
  final maxConnectionsController = TextEditingController();
  final cMaxReuseTimesController = TextEditingController();
  final hMaxReusableSecsController = TextEditingController();
  final hMaxRequestTimesController = TextEditingController();
  final hKeepAlivePeriodController = TextEditingController();

  final addressController = TextEditingController();
  final portController = TextEditingController();

  final xhttpHostController = TextEditingController();
  final xhttpPathController = TextEditingController();

  void updateXhttpMode(XhttpMode value) {
    state.downloadState.xhttpMode = value;
    emit(state.bumped());
  }

  void updateSecurity(StreamSettingsSecurity value) {
    state.downloadState.security = value;
    emit(state.bumped());
  }

  final serverNameController = TextEditingController();

  void updateFingerprint(StreamSettingsSecurityFingerprint value) {
    state.downloadState.fingerprint = value;
    emit(state.bumped());
  }

  void updateAlpn(bool selected, StreamSettingsSecurityALPN value) {
    if (selected) {
      state.downloadState.alpn.add(value);
    } else {
      state.downloadState.alpn.remove(value);
    }
    emit(state.bumped());
  }

  final pinnedPeerCertSha256Controller = TextEditingController();
  final verifyPeerCertByNameController = TextEditingController();

  final echConfigListController = TextEditingController();
  void updateEchForceQuery(StreamSettingsEchForceQuery value) {
    state.downloadState.echForceQuery = value;
    emit(state.bumped());
  }

  final passwordController = TextEditingController();
  final shortIdController = TextEditingController();
  final mldsa65VerifyController = TextEditingController();
  final spiderXController = TextEditingController();

  Future<void> save(BuildContext context) async {
    _mergeInputToState(state.downloadState);

    if (context.mounted) {
      context.pop(state.downloadState);
    }
  }

  void _mergeInputToState(XhttpDownloadState downloadState) {
    _mergeHeaders(downloadState);
    _mergeInput(downloadState);

    downloadState.removeWhitespace();
  }

  void _mergeHeaders(XhttpDownloadState downloadState) {
    final newHeaders = <String, String>{};
    for (final header in state.headers) {
      final key = header.key.text.removeWhitespace;
      if (key.isNotEmpty) {
        final value = header.value.text.removeWhitespace;
        if (value.isNotEmpty) {
          newHeaders[key] = value;
        }
      }
    }
    downloadState.headers = newHeaders;
  }

  void _mergeInput(XhttpDownloadState downloadState) {
    downloadState.xPaddingBytes = xPaddingBytesController.text;

    downloadState.scMaxEachPostBytes = scMaxEachPostBytesController.text;
    downloadState.scMinPostsIntervalMs = scMinPostsIntervalMsController.text;

    downloadState.maxConcurrency = maxConcurrencyController.text;
    downloadState.maxConnections = maxConnectionsController.text;
    downloadState.cMaxReuseTimes = cMaxReuseTimesController.text;
    downloadState.hMaxReusableSecs = hMaxReusableSecsController.text;
    downloadState.hMaxRequestTimes = hMaxRequestTimesController.text;
    downloadState.hKeepAlivePeriod = hKeepAlivePeriodController.text;

    downloadState.address = addressController.text;
    downloadState.port = portController.text;

    downloadState.xhttpHost = xhttpHostController.text;
    downloadState.xhttpPath = xhttpPathController.text;

    downloadState.serverName = serverNameController.text;
    downloadState.pinnedPeerCertSha256 = pinnedPeerCertSha256Controller.text;
    downloadState.verifyPeerCertByName = verifyPeerCertByNameController.text;
    downloadState.echConfigList = echConfigListController.text;
    downloadState.password = passwordController.text;
    downloadState.shortId = shortIdController.text;
    downloadState.mldsa65Verify = mldsa65VerifyController.text;
    downloadState.spiderX = spiderXController.text;
  }
}
