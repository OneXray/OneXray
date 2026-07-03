import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/core/tun/network_interface/params.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/params.dart';
import 'package:onexray/pages/core/tun/selected_app/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/tun_settings/enum.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/tun_settings/state_validator.dart';
import 'package:onexray/pages/main/navigation.dart';

class TunSettingsPageState {
  final TunSettingsState tunSettings;

  TunSettingsPageState({TunSettingsState? tunSettings})
    : tunSettings = tunSettings ?? TunSettingsState();

  TunSettingsPageState _copy() {
    return TunSettingsPageState(tunSettings: tunSettings);
  }
}

class TunSettingsController extends Cubit<TunSettingsPageState> {
  TunSettingsController() : super(TunSettingsPageState()) {
    _readTunSettings();
  }

  final tunDnsIPv4Controller = TextEditingController();
  final tunDnsIPv6Controller = TextEditingController();
  final tunDnsServerNameController = TextEditingController();

  @override
  Future<void> close() {
    tunDnsIPv4Controller.dispose();
    tunDnsIPv6Controller.dispose();
    tunDnsServerNameController.dispose();
    return super.close();
  }

  Future<void> _readTunSettings() async {
    final tunState = TunSettingsState();
    await tunState.readFromPreferences();
    emit(TunSettingsPageState(tunSettings: tunState));
    _initInputs(tunState);
  }

  void _initInputs(TunSettingsState tunState) {
    tunDnsIPv4Controller.text = tunState.tunDnsIPv4;
    tunDnsIPv6Controller.text = tunState.tunDnsIPv6;
    tunDnsServerNameController.text = tunState.dnsServerName;
  }

  void updateEnableDot(bool value) {
    state.tunSettings.enableDot = value;
    emit(state._copy());
  }

  void updateEnableIPv6(bool value) {
    state.tunSettings.enableIPv6 = value;
    emit(state._copy());
  }

  void updateMetricsEnabled(bool value) {
    state.tunSettings.metricsEnabled = value;
    emit(state._copy());
  }

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(
      state.tunSettings.autoOutboundsInterface,
      showAuto: true,
    );
    final networkInterface = await context.pushScoped<String>(
      AppSecondaryDestination.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.tunSettings.autoOutboundsInterface = networkInterface;
      emit(state._copy());
    }
  }

  void updateOnDemandEnabled(bool value) {
    state.tunSettings.onDemandEnabled = value;
    emit(state._copy());
  }

  void appendOnDemandRule() {
    state.tunSettings.onDemandRules.add(OnDemandRuleState());
    emit(state._copy());
  }

  void sortOnDemandRule(int oldIndex, int newIndex) {
    final rules = state.tunSettings.onDemandRules;
    final rule = rules.removeAt(oldIndex);
    var index = newIndex;
    if (newIndex > oldIndex) {
      index = newIndex - 1;
    }
    rules.insert(index, rule);
    emit(state._copy());
  }

  Future<void> editOnDemandRule(BuildContext context, int index) async {
    final params = OnDemandRuleParams(state.tunSettings.onDemandRules[index]);
    final rule = await context.pushScoped<OnDemandRuleState>(
      AppSecondaryDestination.onDemandRule,
      extra: params,
    );
    if (rule != null) {
      state.tunSettings.onDemandRules[index] = rule;
      emit(state._copy());
    }
  }

  void moreAction(IconMenuId menuId, int serverIndex) async {
    state.tunSettings.onDemandRules.removeAt(serverIndex);
    emit(state._copy());
  }

  void updatePerAppVPNMode(String value) {
    final mode = PerAppVPNMode.fromString(value);
    if (mode != null) {
      state.tunSettings.perAppVPNMode = mode;
      emit(state._copy());
    }
  }

  Future<void> editAppList(BuildContext context) async {
    final accepted = await PreferencesKey().readQueryAllPackagesAccepted();
    if (context.mounted) {
      if (accepted) {
        var apps = <String>{};
        switch (state.tunSettings.perAppVPNMode) {
          case PerAppVPNMode.allow:
            apps = state.tunSettings.allowAppList;
            break;
          case PerAppVPNMode.disallow:
            apps = state.tunSettings.disallowAppList;
            break;
        }
        final params = SelectedAppParams(apps);
        final selectedApps = await context.pushScoped<Set<String>>(
          AppSecondaryDestination.selectedApp,
          extra: params,
        );
        if (selectedApps != null) {
          switch (state.tunSettings.perAppVPNMode) {
            case PerAppVPNMode.allow:
              state.tunSettings.allowAppList = selectedApps;
              break;
            case PerAppVPNMode.disallow:
              state.tunSettings.disallowAppList = selectedApps;
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
          AppLocalizations.of(context)!.tunSettingsPagePerAppVPNPermission,
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
    _mergeInputToState(state.tunSettings);
    emit(state._copy());

    final checked = await _validate(context);
    if (checked) {
      await state.tunSettings.saveToPreferences();
      if (context.mounted) {
        context.pop();
      }
    }
  }

  void _mergeInputToState(TunSettingsState tunState) {
    _mergeInput(tunState);
    tunState.removeWhitespace();
  }

  void _mergeInput(TunSettingsState tunState) {
    tunState.tunDnsIPv4 = tunDnsIPv4Controller.text;
    tunState.tunDnsIPv6 = tunDnsIPv6Controller.text;
    tunState.dnsServerName = tunDnsServerNameController.text;
  }

  Future<bool> _validate(BuildContext context) async {
    final tuple = await state.tunSettings.validate();
    if (!context.mounted) {
      return false;
    }
    if (!tuple.item1) {
      ContextAlert.showToast(context, tuple.item2);
    }
    return tuple.item1;
  }
}
