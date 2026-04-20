import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/sub_update/state.dart';

class SubUpdatePageState {
  final SubUpdateState subUpdateState;

  SubUpdatePageState({SubUpdateState? subUpdateState})
      : subUpdateState = subUpdateState ?? SubUpdateState();

  SubUpdatePageState _copy() {
    return SubUpdatePageState(subUpdateState: subUpdateState);
  }
}

class SubUpdateController extends Cubit<SubUpdatePageState> {
  SubUpdateController() : super(SubUpdatePageState()) {
    _readSubUpdateState();
  }

  Future<void> _readSubUpdateState() async {
    final subUpdateState = SubUpdateState();
    await subUpdateState.readFromPreferences();
    emit(SubUpdatePageState(subUpdateState: subUpdateState));
  }

  void updateEnable(bool value) {
    state.subUpdateState.enable = value;
    emit(state._copy());
  }

  void updateInterval(SubUpdateInterval value) {
    state.subUpdateState.interval = value;
    emit(state._copy());
  }

  void updateAutoPing(bool value) {
    state.subUpdateState.autoPing = value;
    emit(state._copy());
  }

  Future<void> save(BuildContext context) async {
    await state.subUpdateState.saveToPreferences();
    if (context.mounted) {
      context.pop();
    }
  }
}
