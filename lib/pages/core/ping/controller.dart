import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/ping/state.dart';

class PingPageState {
  final PingState pingState;

  PingPageState({PingState? pingState}) : pingState = pingState ?? PingState();

  PingPageState _copy() {
    return PingPageState(pingState: pingState);
  }
}

class PingController extends Cubit<PingPageState> {
  PingController() : super(PingPageState()) {
    _readPingState();
  }

  Future<void> _readPingState() async {
    final pingState = PingState();
    await pingState.readFromPreferences();
    emit(PingPageState(pingState: pingState));
  }

  void updateTimeout(double value) {
    state.pingState.timeout = value;
    emit(state._copy());
  }

  void updateConcurrency(double value) {
    state.pingState.concurrency = value;
    emit(state._copy());
  }

  void updateUrl(String value) {
    final url = PingUrl.fromString(value);
    if (url != null) {
      state.pingState.url = url;
      emit(state._copy());
    }
  }

  void updateAutoPingNewConfigs(bool value) {
    state.pingState.autoPingNewConfigs = value;
    emit(state._copy());
  }

  Future<void> save(BuildContext context) async {
    await state.pingState.saveToPreferences();
    if (context.mounted) {
      context.pop();
    }
  }
}
