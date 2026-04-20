import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/pages/setting/tun/installed_app/params.dart';

class InstalledAppState {
  final List<AndroidAppInfo> apps;
  final Set<String> selections;

  const InstalledAppState({
    this.apps = const [],
    this.selections = const {},
  });

  InstalledAppState copyWith({
    List<AndroidAppInfo>? apps,
    Set<String>? selections,
  }) {
    return InstalledAppState(
      apps: apps ?? this.apps,
      selections: selections ?? this.selections,
    );
  }
}

class InstalledAppController extends Cubit<InstalledAppState> {
  final InstalledAppParams params;

  InstalledAppController(this.params) : super(const InstalledAppState()) {
    _initParams();
  }

  final _allApps = <AndroidAppInfo>[];
  final searchController = TextEditingController();

  @override
  Future<void> close() {
    searchController.dispose();
    return super.close();
  }

  void _initParams() {
    _allApps.clear();
    _allApps.addAll(params.allApps);
    emit(InstalledAppState(
      apps: List.from(_allApps),
      selections: Set.from(params.selections),
    ));
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
