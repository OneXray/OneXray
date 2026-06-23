import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/setting/fake_dns/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/xray/setting/fake_dns_state.dart';

class FakeDnsCubitState {
  final FakeDnsPoolsState fakeDnsState;
  final int version;

  const FakeDnsCubitState({required this.fakeDnsState, this.version = 0});

  factory FakeDnsCubitState.initial() =>
      FakeDnsCubitState(fakeDnsState: FakeDnsPoolsState());

  FakeDnsCubitState bumped() =>
      FakeDnsCubitState(fakeDnsState: fakeDnsState, version: version + 1);
}

class FakeDnsController extends Cubit<FakeDnsCubitState> {
  final FakeDnsParams params;
  FakeDnsController(this.params) : super(FakeDnsCubitState.initial()) {
    _initParams();
  }

  final ipv4IpPoolController = TextEditingController();
  final ipv4PoolSizeController = TextEditingController();
  final ipv6IpPoolController = TextEditingController();
  final ipv6PoolSizeController = TextEditingController();

  @override
  Future<void> close() {
    ipv4IpPoolController.dispose();
    ipv4PoolSizeController.dispose();
    ipv6IpPoolController.dispose();
    ipv6PoolSizeController.dispose();
    return super.close();
  }

  void _initParams() {
    final initS = params.state;
    _initInput(initS);
    emit(FakeDnsCubitState(fakeDnsState: initS, version: 1));
  }

  void _initInput(FakeDnsPoolsState state) {
    ipv4IpPoolController.text = state.ipv4.ipPool;
    ipv4PoolSizeController.text = state.ipv4.poolSize;
    ipv6IpPoolController.text = state.ipv6.ipPool;
    ipv6PoolSizeController.text = state.ipv6.poolSize;
  }

  void save(BuildContext context) {
    _mergeInputToState(state.fakeDnsState);
    final message = _validate(context, state.fakeDnsState);
    if (message != null) {
      ContextAlert.showToast(context, message);
      return;
    }
    context.pop<FakeDnsPoolsState>(state.fakeDnsState);
  }

  void _mergeInputToState(FakeDnsPoolsState state) {
    state.ipv4.ipPool = ipv4IpPoolController.text;
    state.ipv4.poolSize = ipv4PoolSizeController.text;
    state.ipv6.ipPool = ipv6IpPoolController.text;
    state.ipv6.poolSize = ipv6PoolSizeController.text;

    state.removeWhitespace();
  }

  String? _validate(BuildContext context, FakeDnsPoolsState state) {
    final appLocalizations = AppLocalizations.of(context)!;
    final ipv4Error = state.validateIPv4();
    if (ipv4Error != null) {
      return "${appLocalizations.fakeDnsPageIPv4}: ${_errorMessage(appLocalizations, ipv4Error)}";
    }
    final ipv6Error = state.validateIPv6();
    if (ipv6Error != null) {
      return "${appLocalizations.fakeDnsPageIPv6}: ${_errorMessage(appLocalizations, ipv6Error)}";
    }
    return null;
  }

  String _errorMessage(
    AppLocalizations appLocalizations,
    FakeDnsValidationError error,
  ) {
    switch (error) {
      case FakeDnsValidationError.ipPoolRequired:
        return appLocalizations.fakeDnsValidationIpPoolRequired;
      case FakeDnsValidationError.ipPoolInvalid:
        return appLocalizations.fakeDnsValidationIpPoolInvalid;
      case FakeDnsValidationError.poolSizeInvalid:
        return appLocalizations.fakeDnsValidationPoolSizeInvalid;
      case FakeDnsValidationError.poolSizeTooLarge:
        return appLocalizations.fakeDnsValidationPoolSizeTooLarge;
    }
  }
}
