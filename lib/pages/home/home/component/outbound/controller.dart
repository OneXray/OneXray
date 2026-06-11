import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class HomeOutboundState {
  final String xraySettingName;
  final List<ConfigQueryRow> configs;
  final String query;
  final bool searching;

  const HomeOutboundState({
    required this.xraySettingName,
    required this.configs,
    required this.query,
    required this.searching,
  });

  factory HomeOutboundState.initial({
    int xraySettingId = DBConstants.defaultId,
  }) => HomeOutboundState(
    xraySettingName: _initialXraySettingName(xraySettingId),
    configs: const [],
    query: "",
    searching: false,
  );

  HomeOutboundState copyWith({
    String? xraySettingName,
    List<ConfigQueryRow>? configs,
    String? query,
    bool? searching,
  }) {
    return HomeOutboundState(
      xraySettingName: xraySettingName ?? this.xraySettingName,
      configs: configs ?? this.configs,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

String _initialXraySettingName(int xraySettingId) {
  switch (xraySettingId) {
    case DBConstants.defaultId:
      return appLocalizationsNoContext().settingNotSet;
    case XraySettingSimple.simpleId:
      return appLocalizationsNoContext().xraySettingListPageSimple;
    default:
      return "";
  }
}

class HomeOutboundController extends Cubit<HomeOutboundState> {
  HomeOutboundController()
    : super(
        HomeOutboundState.initial(
          xraySettingId: AppEventBus.instance.state.xraySettingId,
        ),
      ) {
    _asyncInit();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  StreamSubscription<int>? _xraySettingSubscription;
  final searchController = TextEditingController();
  var _allConfigs = <ConfigQueryRow>[];

  Future<void> _asyncInit() async {
    final db = AppDatabase();
    _configsSubscription = db.coreConfigDao.allOutboundRowsStream().listen((
      data,
    ) {
      _allConfigs = data;
      _emitFilteredConfigs();
    });
    await _listenXraySetting();
  }

  Future<void> _listenXraySetting() async {
    final eventBus = AppEventBus.instance;
    var xraySettingId = eventBus.state.xraySettingId;
    if (xraySettingId == DBConstants.defaultId) {
      xraySettingId = await PreferencesKey().readXraySettingId();
    }
    await _readXraySetting(xraySettingId);

    _xraySettingSubscription = eventBus.stream
        .map((s) => s.xraySettingId)
        .distinct()
        .listen((data) => _readXraySetting(data));
  }

  Future<void> _readXraySetting(int id) async {
    switch (id) {
      case DBConstants.defaultId:
        emit(
          state.copyWith(
            xraySettingName: appLocalizationsNoContext().settingNotSet,
          ),
        );
        break;
      case XraySettingSimple.simpleId:
        emit(
          state.copyWith(
            xraySettingName:
                appLocalizationsNoContext().xraySettingListPageSimple,
          ),
        );
        break;
      default:
        final db = AppDatabase();
        final xraySettingData = await db.coreConfigDao.searchRow(id);
        if (xraySettingData != null) {
          emit(state.copyWith(xraySettingName: xraySettingData.name));
        } else {
          emit(
            state.copyWith(
              xraySettingName: appLocalizationsNoContext().settingNotSet,
            ),
          );
        }
        break;
    }
  }

  void gotoXraySetting(BuildContext context) {
    context.push(RouterPath.xraySettingList);
  }

  Future<void> ping(int subId) async {
    await PingService().pingOutboundConfigs(subId);
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    _allConfigs = await db.coreConfigDao.allOutboundRows;
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
    _xraySettingSubscription?.cancel();
    return super.close();
  }
}
