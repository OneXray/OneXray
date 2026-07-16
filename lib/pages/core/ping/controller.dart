import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/ping/state.dart';

class PingPageState {
  final PingState pingState;

  PingPageState({PingState? pingState}) : pingState = pingState ?? PingState();

  PingPageState _copy() {
    return PingPageState(pingState: pingState);
  }
}

class PingController extends PageCubit<PingPageState> {
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

  Future<void> copyResolvedUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: state.pingState.url.url));
    if (context.mounted) {
      final localizations = AppLocalizations.of(context)!;
      ContextAlert.showToast(
        context,
        localizations.actionResult(
          localizations.menuCopy,
          localizations.resultSuccess,
        ),
      );
    }
  }

  Future<void> save(BuildContext context) async {
    await state.pingState.saveToPreferences();
    if (context.mounted) {
      context.pop();
    }
  }
}
