import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/xray/setting/metrics/params.dart';
import 'package:onexray/service/xray/setting/metrics_state.dart';

class MetricsCubitState {
  final MetricsState metricsState;
  final int version;

  const MetricsCubitState({required this.metricsState, this.version = 0});

  factory MetricsCubitState.initial() =>
      MetricsCubitState(metricsState: MetricsState());

  MetricsCubitState bumped() =>
      MetricsCubitState(metricsState: metricsState, version: version + 1);
}

class MetricsController extends Cubit<MetricsCubitState> {
  final MetricsParams params;

  MetricsController(this.params) : super(MetricsCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(MetricsCubitState(metricsState: params.state.copy, version: 1));
  }

  void updateEnabled(bool value) {
    state.metricsState.enabled = value;
    emit(state.bumped());
  }

  String listenValue(BuildContext context) {
    if (!state.metricsState.enabled) {
      return AppLocalizations.of(context)!.chainProxyPageDisabled;
    }
    return state.metricsState.displayListen;
  }

  bool get listenRowEnabled => state.metricsState.enabled;

  void save(BuildContext context) {
    context.pop<MetricsState>(state.metricsState);
  }
}
