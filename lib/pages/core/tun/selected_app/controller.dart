import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/pages/core/tun/installed_app/params.dart';
import 'package:onexray/pages/core/tun/selected_app/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/widget/menu_picker.dart';

class SelectedAppPageState {
  final List<AndroidAppInfo> apps;

  const SelectedAppPageState({this.apps = const []});

  SelectedAppPageState copyWith({List<AndroidAppInfo>? apps}) {
    return SelectedAppPageState(apps: apps ?? this.apps);
  }
}

class SelectedAppController extends Cubit<SelectedAppPageState> {
  final SelectedAppParams params;

  SelectedAppController(this.params) : super(const SelectedAppPageState()) {
    _initParams();
    _queryApps();
  }

  final _allApps = <AndroidAppInfo>[];
  final _selections = <String>{};

  void _initParams() {
    _selections.clear();
    _selections.addAll(params.apps);
  }

  Future<void> _queryApps() async {
    final androidApps = await AppHostApi().getInstalledApps();
    _allApps.clear();
    _allApps.addAll(androidApps);

    _refreshApps();
  }

  void _refreshApps() {
    final selections = <String>{};
    final selectedApps = <AndroidAppInfo>[];
    for (final app in _allApps) {
      for (final selection in _selections) {
        if (app.packageName == selection) {
          selections.add(selection);
          selectedApps.add(app);
        }
      }
    }
    _selections.clear();
    _selections.addAll(selections);

    emit(state.copyWith(apps: selectedApps));
  }

  void moreAction(
    BuildContext context,
    AndroidAppInfo appInfo,
    IconMenuId menuId,
  ) {
    _selections.remove(appInfo.packageName);
    final newApps = List<AndroidAppInfo>.from(state.apps)..remove(appInfo);
    emit(state.copyWith(apps: newApps));
  }

  Future<void> gotoInstalledApp(BuildContext context) async {
    final params = InstalledAppParams(_allApps, _selections);
    final selectedApps = await context.pushScoped<Set<String>>(
      AppSecondaryDestination.installedApp,
      extra: params,
    );
    if (selectedApps != null) {
      _selections.clear();
      _selections.addAll(selectedApps);
      _refreshApps();
    }
  }

  void save(BuildContext context) {
    context.pop(_selections);
  }
}
