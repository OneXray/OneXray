import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/log/params.dart';
import 'package:onexray/service/xray/profile/log_state.dart';

class XrayLogPageState {
  final LogState logState;
  final int version;

  const XrayLogPageState({required this.logState, this.version = 0});

  factory XrayLogPageState.initial() => XrayLogPageState(logState: LogState());

  XrayLogPageState bumped() =>
      XrayLogPageState(logState: logState, version: version + 1);
}

class XrayLogController extends Cubit<XrayLogPageState> {
  final XrayLogParams params;
  XrayLogController(this.params) : super(XrayLogPageState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(XrayLogPageState(logState: params.state, version: 1));
  }

  void updateLogLevel(String value) {
    final logLevel = XrayLogLevel.fromString(value);
    if (logLevel != null) {
      state.logState.logLevel = logLevel;
      emit(state.bumped());
    }
  }

  void updateDnsLog(bool value) {
    state.logState.dnsLog = value;
    emit(state.bumped());
  }

  void updateMaskAddress(String value) {
    final maskAddress = XrayLogMaskAddress.fromString(value);
    if (maskAddress != null) {
      state.logState.maskAddress = maskAddress;
      emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    context.pop<LogState>(state.logState);
  }
}
