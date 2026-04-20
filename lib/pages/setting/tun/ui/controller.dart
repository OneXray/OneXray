import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/setting/tun/network_interface/params.dart';
import 'package:onexray/pages/setting/tun/on_demand_rule/params.dart';
import 'package:onexray/pages/setting/tun/selected_app/params.dart';
import 'package:onexray/service/tun_setting/enum.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/service/tun_setting/state_validator.dart';

class TunSettingUIState {
  final TunSettingState tunSettingState;

  TunSettingUIState({TunSettingState? tunSettingState})
      : tunSettingState = tunSettingState ?? TunSettingState();

  TunSettingUIState _copy() {
    return TunSettingUIState(tunSettingState: tunSettingState);
  }
}

class TunSettingUIController extends Cubit<TunSettingUIState> {
  TunSettingUIController() : super(TunSettingUIState()) {
    _readTunSetting();
  }

  final tunPriorityController = TextEditingController();
  final tunDnsIPv4Controller = TextEditingController();
  final tunDnsIPv6Controller = TextEditingController();
  final tunDnsServerNameController = TextEditingController();

  @override
  Future<void> close() {
    tunPriorityController.dispose();
    tunDnsIPv4Controller.dispose();
    tunDnsIPv6Controller.dispose();
    tunDnsServerNameController.dispose();
    return super.close();
  }

  Future<void> _readTunSetting() async {
    final tunState = TunSettingState();
    await tunState.readFromPreferences();
    emit(TunSettingUIState(tunSettingState: tunState));
    _initInputs(tunState);
  }

  void _initInputs(TunSettingState tunState) {
    tunPriorityController.text = tunState.tunPriority;
    tunDnsIPv4Controller.text = tunState.tunDnsIPv4;
    tunDnsIPv6Controller.text = tunState.tunDnsIPv6;
    tunDnsServerNameController.text = tunState.dnsServerName;
  }

  void updateEnableDot(bool value) {
    state.tunSettingState.enableDot = value;
    emit(state._copy());
  }

  void updateEnableIPv6(bool value) {
    state.tunSettingState.enableIPv6 = value;
    emit(state._copy());
  }

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(state.tunSettingState.bindInterface);
    final networkInterface = await context.push<String>(
      RouterPath.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.tunSettingState.bindInterface = networkInterface;
      emit(state._copy());
    }
  }

  void updateOnDemandEnabled(bool value) {
    state.tunSettingState.onDemandEnabled = value;
    emit(state._copy());
  }

  void appendOnDemandRule() {
    state.tunSettingState.onDemandRules.add(OnDemandRuleState());
    emit(state._copy());
  }

  void sortOnDemandRule(int oldIndex, int newIndex) {
    final rules = state.tunSettingState.onDemandRules;
    final rule = rules.removeAt(oldIndex);
    var index = newIndex;
    if (newIndex > oldIndex) {
      index = newIndex - 1;
    }
    rules.insert(index, rule);
    emit(state._copy());
  }

  Future<void> editOnDemandRule(BuildContext context, int index) async {
    final params = OnDemandRuleParams(
      state.tunSettingState.onDemandRules[index],
    );
    final rule = await context.push<OnDemandRuleState>(
      RouterPath.onDemandRule,
      extra: params,
    );
    if (rule != null) {
      state.tunSettingState.onDemandRules[index] = rule;
      emit(state._copy());
    }
  }

  void moreAction(String menuId, int serverIndex) async {
    state.tunSettingState.onDemandRules.removeAt(serverIndex);
    emit(state._copy());
  }

  void updatePerAppVPNMode(String value) {
    final mode = PerAppVPNMode.fromString(value);
    if (mode != null) {
      state.tunSettingState.perAppVPNMode = mode;
      emit(state._copy());
    }
  }

  Future<void> editAppList(BuildContext context) async {
    final accepted = await PreferencesKey().readQueryAllPackagesAccepted();
    if (context.mounted) {
      if (accepted) {
        var apps = <String>{};
        switch (state.tunSettingState.perAppVPNMode) {
          case PerAppVPNMode.allow:
            apps = state.tunSettingState.allowAppList;
            break;
          case PerAppVPNMode.disallow:
            apps = state.tunSettingState.disallowAppList;
            break;
        }
        final params = SelectedAppParams(apps);
        final selectedApps = await context.push<Set<String>>(
          RouterPath.selectedApp,
          extra: params,
        );
        if (selectedApps != null) {
          switch (state.tunSettingState.perAppVPNMode) {
            case PerAppVPNMode.allow:
              state.tunSettingState.allowAppList = selectedApps;
              break;
            case PerAppVPNMode.disallow:
              state.tunSettingState.disallowAppList = selectedApps;
              break;
          }
          emit(state._copy());
        }
      } else {
        await _showPermissionDialog(context);
      }
    }
  }

  Future<void> _showPermissionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          AppLocalizations.of(context)!.tunSettingUIPagePerAppVPNPermission,
        ),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.buttonDecline),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.buttonAccept),
            onPressed: () {
              Navigator.pop(ctx);
              _acceptPermission(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _acceptPermission(BuildContext context) async {
    await PreferencesKey().saveQueryAllPackagesAccepted(true);
    if (context.mounted) {
      await editAppList(context);
    }
  }

  Future<void> save(BuildContext context) async {
    _mergeInputToState(state.tunSettingState);
    emit(state._copy());

    final checked = await _validate(context);
    if (checked) {
      await state.tunSettingState.saveToPreferences();
      if (context.mounted) {
        context.pop();
      }
    }
  }

  void _mergeInputToState(TunSettingState tunState) {
    _mergeInput(tunState);
    tunState.removeWhitespace();
  }

  void _mergeInput(TunSettingState tunState) {
    tunState.tunPriority = tunPriorityController.text;
    tunState.tunDnsIPv4 = tunDnsIPv4Controller.text;
    tunState.tunDnsIPv6 = tunDnsIPv6Controller.text;
    tunState.dnsServerName = tunDnsServerNameController.text;
  }

  Future<bool> _validate(BuildContext context) async {
    final tuple = await state.tunSettingState.validate();
    if (!context.mounted) {
      return false;
    }
    if (!tuple.item1) {
      ContextAlert.showToast(context, tuple.item2);
    }
    return tuple.item1;
  }
}
