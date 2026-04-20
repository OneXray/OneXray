import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class HomeOutboundState {
  final String xraySettingName;
  final List<ConfigQueryRow> configs;

  const HomeOutboundState({
    required this.xraySettingName,
    required this.configs,
  });

  factory HomeOutboundState.initial() => HomeOutboundState(
        xraySettingName: appLocalizationsNoContext().settingNotSet,
        configs: const [],
      );

  HomeOutboundState copyWith({
    String? xraySettingName,
    List<ConfigQueryRow>? configs,
  }) {
    return HomeOutboundState(
      xraySettingName: xraySettingName ?? this.xraySettingName,
      configs: configs ?? this.configs,
    );
  }
}

class HomeOutboundController extends Cubit<HomeOutboundState> {
  HomeOutboundController() : super(HomeOutboundState.initial()) {
    _asyncInit();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  StreamSubscription<int>? _xraySettingSubscription;

  Future<void> _asyncInit() async {
    final db = AppDatabase();
    _configsSubscription = db.coreConfigDao.allOutboundRowsStream().listen(
      (data) => emit(state.copyWith(configs: data)),
    );
    await _listenXraySetting();
  }

  Future<void> _listenXraySetting() async {
    final xraySettingId = await PreferencesKey().readXraySettingId();
    _readXraySetting(xraySettingId);

    final eventBus = AppEventBus.instance;
    _xraySettingSubscription = eventBus.stream
        .map((s) => s.xraySettingId)
        .distinct()
        .listen((data) => _readXraySetting(data));
  }

  Future<void> _readXraySetting(int id) async {
    switch (id) {
      case DBConstants.defaultId:
        emit(state.copyWith(
          xraySettingName: appLocalizationsNoContext().settingNotSet,
        ));
        break;
      case XraySettingSimple.simpleId:
        emit(state.copyWith(xraySettingName: XraySettingSimple.simpleName));
        break;
      default:
        final db = AppDatabase();
        final xraySettingData = await db.coreConfigDao.searchRow(id);
        if (xraySettingData != null) {
          emit(state.copyWith(xraySettingName: xraySettingData.name));
        } else {
          emit(state.copyWith(
            xraySettingName: appLocalizationsNoContext().settingNotSet,
          ));
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
    final newList = await db.coreConfigDao.allOutboundRows;
    emit(state.copyWith(configs: newList));
  }

  @override
  Future<void> close() {
    _configsSubscription?.cancel();
    _xraySettingSubscription?.cancel();
    return super.close();
  }
}
