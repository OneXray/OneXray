import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/auto_update/state.dart';

class AutoUpdatePageState {
  final AutoUpdateState autoUpdateState;

  AutoUpdatePageState({AutoUpdateState? autoUpdateState})
    : autoUpdateState = autoUpdateState ?? AutoUpdateState();

  AutoUpdatePageState _copy() {
    return AutoUpdatePageState(autoUpdateState: autoUpdateState);
  }
}

class AutoUpdateController extends PageCubit<AutoUpdatePageState> {
  AutoUpdateController() : super(AutoUpdatePageState()) {
    _readAutoUpdateState();
  }

  Future<void> _readAutoUpdateState() async {
    final autoUpdateState = AutoUpdateState();
    await autoUpdateState.readFromPreferences();
    emit(AutoUpdatePageState(autoUpdateState: autoUpdateState));
  }

  void updateSubscriptionEnabled(bool value) {
    state.autoUpdateState.subscriptionEnabled = value;
    emit(state._copy());
  }

  void updateSubscriptionInterval(AutoUpdateInterval value) {
    state.autoUpdateState.subscriptionInterval = value;
    emit(state._copy());
  }

  void updateGeoDataEnable(bool value) {
    state.autoUpdateState.geoDataEnable = value;
    emit(state._copy());
  }

  void updateGeoDataInterval(AutoUpdateInterval value) {
    state.autoUpdateState.geoDataInterval = value;
    emit(state._copy());
  }

  void updateGeoDataUpdateAfterVpnConnected(bool value) {
    state.autoUpdateState.geoDataUpdateAfterVpnConnected = value;
    emit(state._copy());
  }

  Future<void> save(BuildContext context) async {
    await state.autoUpdateState.saveToPreferences();
    if (context.mounted) {
      context.pop();
    }
  }
}
