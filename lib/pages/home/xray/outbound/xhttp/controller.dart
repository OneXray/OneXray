import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/download_settings/params.dart';
import 'package:onexray/pages/home/xray/outbound/xhttp/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state.dart';
import 'package:onexray/service/xray/outbound/xhttp/state.dart';
import 'package:onexray/service/xray/outbound/xhttp/state_validator.dart';

class OutboundXhttpHeader {
  final key = TextEditingController();
  final value = TextEditingController();
}

class OutboundXhttpState {
  final XhttpMode mode;
  final XhttpExtraState extraState;
  final List<OutboundXhttpHeader> headers;
  final int version;

  const OutboundXhttpState({
    required this.mode,
    required this.extraState,
    required this.headers,
    this.version = 0,
  });

  factory OutboundXhttpState.initial() => OutboundXhttpState(
        mode: XhttpMode.auto,
        extraState: XhttpExtraState(),
        headers: const [],
      );

  OutboundXhttpState bumped() => OutboundXhttpState(
        mode: mode,
        extraState: extraState,
        headers: headers,
        version: version + 1,
      );
}

class OutboundXhttpController extends Cubit<OutboundXhttpState> {
  final OutboundXhttpParams params;
  OutboundXhttpController(this.params) : super(OutboundXhttpState.initial()) {
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

    for (final controller in state.headers) {
      controller.key.dispose();
      controller.value.dispose();
    }

    return super.close();
  }

  void _initParams() {
    final extraState = params.state;
    final headers = <OutboundXhttpHeader>[];
    _initHeaders(extraState, headers);
    _initInput(extraState);
    emit(OutboundXhttpState(
      mode: params.mode,
      extraState: extraState,
      headers: headers,
      version: 1,
    ));
  }

  void _initHeaders(XhttpExtraState extraState, List<OutboundXhttpHeader> headers) {
    extraState.headers.forEach((k, v) {
      final header = OutboundXhttpHeader();
      header.key.text = k;
      header.value.text = v;
      headers.add(header);
    });
  }

  void _initInput(XhttpExtraState extraState) {
    xPaddingBytesController.text = extraState.xPaddingBytes;

    scMaxEachPostBytesController.text = extraState.scMaxEachPostBytes;
    scMinPostsIntervalMsController.text = extraState.scMinPostsIntervalMs;

    maxConcurrencyController.text = extraState.maxConcurrency;
    maxConnectionsController.text = extraState.maxConnections;
    cMaxReuseTimesController.text = extraState.cMaxReuseTimes;
    hMaxReusableSecsController.text = extraState.hMaxReusableSecs;
    hMaxRequestTimesController.text = extraState.hMaxRequestTimes;
    hKeepAlivePeriodController.text = extraState.hKeepAlivePeriod;
  }

  void appendHeader() {
    state.headers.add(OutboundXhttpHeader());
    emit(state.bumped());
  }

  final xPaddingBytesController = TextEditingController();

  void updateNoGRPCHeader(bool value) {
    state.extraState.noGRPCHeader = value;
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

  Future<void> editXhttpDownloadSettings(BuildContext context) async {
    final params = XhttpDownloadSettingsParams(
      state.extraState.downloadSettings,
    );
    final xhttpDownloadSettings = await context.push<XhttpDownloadState>(
      RouterPath.xhttpDownloadSettings,
      extra: params,
    );
    if (xhttpDownloadSettings != null) {
      state.extraState.downloadSettings = xhttpDownloadSettings;
      emit(state.bumped());
    }
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(state.extraState);

    if (context.mounted) {
      context.pop(state.extraState);
    }
  }

  void _mergeInputToState(XhttpExtraState extraState) {
    _mergeHeaders(extraState);
    _mergeInput(extraState);

    extraState.removeWhitespace();
  }

  void _mergeHeaders(XhttpExtraState extraState) {
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
    extraState.headers = newHeaders;
  }

  void _mergeInput(XhttpExtraState extraState) {
    extraState.xPaddingBytes = xPaddingBytesController.text;

    extraState.scMaxEachPostBytes = scMaxEachPostBytesController.text;
    extraState.scMinPostsIntervalMs = scMinPostsIntervalMsController.text;

    extraState.maxConcurrency = maxConcurrencyController.text;
    extraState.maxConnections = maxConnectionsController.text;
    extraState.cMaxReuseTimes = cMaxReuseTimesController.text;
    extraState.hMaxReusableSecs = hMaxReusableSecsController.text;
    extraState.hMaxRequestTimes = hMaxRequestTimesController.text;
    extraState.hKeepAlivePeriod = hKeepAlivePeriodController.text;
  }
}
