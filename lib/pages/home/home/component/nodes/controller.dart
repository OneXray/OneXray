import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class HomeNodePageState {
  final String xrayProfileName;
  final List<ConfigQueryRow> configs;
  final String query;
  final bool searching;

  const HomeNodePageState({
    required this.xrayProfileName,
    required this.configs,
    required this.query,
    required this.searching,
  });

  factory HomeNodePageState.initial({
    int xrayProfileId = DBConstants.defaultId,
  }) => HomeNodePageState(
    xrayProfileName: _initialXrayProfileName(xrayProfileId),
    configs: const [],
    query: "",
    searching: false,
  );

  HomeNodePageState copyWith({
    String? xrayProfileName,
    List<ConfigQueryRow>? configs,
    String? query,
    bool? searching,
  }) {
    return HomeNodePageState(
      xrayProfileName: xrayProfileName ?? this.xrayProfileName,
      configs: configs ?? this.configs,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

String _initialXrayProfileName(int xrayProfileId) {
  switch (xrayProfileId) {
    case DBConstants.defaultId:
      return appLocalizationsNoContext().xrayProfileListPageSimple;
    case XrayProfileSimple.simpleId:
      return appLocalizationsNoContext().xrayProfileListPageSimple;
    default:
      return "";
  }
}

class HomeNodeController extends Cubit<HomeNodePageState> {
  HomeNodeController()
    : super(
        HomeNodePageState.initial(
          xrayProfileId: AppEventBus.instance.state.xrayProfileId,
        ),
      ) {
    _asyncInit();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  StreamSubscription<int>? _xrayProfileSubscription;
  final searchController = TextEditingController();
  var _allConfigs = <ConfigQueryRow>[];

  Future<void> _asyncInit() async {
    final db = AppDatabase();
    _configsSubscription = db.coreConfigDao.allHomeNodeRowsStream().listen((
      data,
    ) {
      _allConfigs = data;
      _emitFilteredConfigs();
    });
    await _listenXrayProfile();
  }

  Future<void> _listenXrayProfile() async {
    final eventBus = AppEventBus.instance;
    var xrayProfileId = eventBus.state.xrayProfileId;
    xrayProfileId = await PreferencesKey().readXrayProfileId();
    await _readXrayProfile(xrayProfileId);

    _xrayProfileSubscription = eventBus.stream
        .map((s) => s.xrayProfileId)
        .distinct()
        .listen((data) => _readXrayProfile(data));
  }

  Future<void> _readXrayProfile(int id) async {
    switch (id) {
      case DBConstants.defaultId:
        emit(
          state.copyWith(
            xrayProfileName:
                appLocalizationsNoContext().xrayProfileListPageSimple,
          ),
        );
        break;
      case XrayProfileSimple.simpleId:
        emit(
          state.copyWith(
            xrayProfileName:
                appLocalizationsNoContext().xrayProfileListPageSimple,
          ),
        );
        break;
      default:
        final db = AppDatabase();
        final xrayProfileData = await db.coreConfigDao.searchRow(id);
        if (xrayProfileData != null) {
          emit(state.copyWith(xrayProfileName: xrayProfileData.name));
        } else {
          emit(
            state.copyWith(
              xrayProfileName:
                  appLocalizationsNoContext().xrayProfileListPageSimple,
            ),
          );
        }
        break;
    }
  }

  void gotoXrayProfile(BuildContext context) {
    context.goScoped(AppSecondaryDestination.xray);
  }

  Future<void> ping(int subId) async {
    await PingService().pingHomeNodeConfigs(subId);
  }

  Future<void> cleanUnreachable(int subId) async {
    final db = AppDatabase();
    await db.coreConfigDao.deleteUnreachableHomeNodeRows(subId);
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    _allConfigs = await db.coreConfigDao.allHomeNodeRows;
    _emitFilteredConfigs();
  }

  void updateSearchQuery(String value) {
    _emitFilteredConfigs(query: value);
  }

  void toggleSearch() {
    if (state.searching) {
      searchController.clear();
      _emitFilteredConfigs(query: "", searching: false);
    } else {
      emit(state.copyWith(searching: true));
    }
  }

  void _emitFilteredConfigs({String? query, bool? searching}) {
    final nextQuery = query ?? state.query;
    final configs = ConfigQueryFilter.filterRows(_allConfigs, nextQuery);
    emit(
      state.copyWith(configs: configs, query: nextQuery, searching: searching),
    );
  }

  @override
  Future<void> close() {
    searchController.dispose();
    _configsSubscription?.cancel();
    _xrayProfileSubscription?.cancel();
    return super.close();
  }
}
