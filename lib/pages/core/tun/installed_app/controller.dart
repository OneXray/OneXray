import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/pages/core/tun/installed_app/params.dart';

class InstalledAppPageState {
  final List<AndroidAppInfo> apps;
  final Set<String> selections;

  const InstalledAppPageState({
    this.apps = const [],
    this.selections = const {},
  });

  InstalledAppPageState copyWith({
    List<AndroidAppInfo>? apps,
    Set<String>? selections,
  }) {
    return InstalledAppPageState(
      apps: apps ?? this.apps,
      selections: selections ?? this.selections,
    );
  }
}

class InstalledAppController extends PageCubit<InstalledAppPageState> {
  final InstalledAppParams params;

  InstalledAppController(this.params) : super(const InstalledAppPageState()) {
    _initParams();
  }

  final _allApps = <AndroidAppInfo>[];
  final searchController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    searchController.dispose();
  }

  void _initParams() {
    _allApps.clear();
    _allApps.addAll(params.allApps);
    emit(
      InstalledAppPageState(
        apps: List.from(_allApps),
        selections: Set.from(params.selections),
      ),
    );
  }

  void updateSelections(bool? checked, String packageName) {
    if (checked != null) {
      final newSelections = Set<String>.from(state.selections);
      if (checked) {
        newSelections.add(packageName);
      } else {
        newSelections.remove(packageName);
      }
      emit(state.copyWith(selections: newSelections));
    }
  }

  void keywordChanged(String value) {
    if (value.isNotEmpty) {
      final filterApps = _allApps
          .where((e) => e.name.toLowerCase().contains(value.toLowerCase()))
          .toList();
      emit(state.copyWith(apps: filterApps));
    } else {
      emit(state.copyWith(apps: List.from(_allApps)));
    }
  }

  void save(BuildContext context) {
    context.pop(state.selections);
  }
}
