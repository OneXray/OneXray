import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:flutter/material.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/service/ping/service.dart';

class HomeRawState {
  final List<ConfigQueryRow> configs;
  final String query;
  final bool searching;

  const HomeRawState({
    required this.configs,
    required this.query,
    required this.searching,
  });

  factory HomeRawState.initial() =>
      const HomeRawState(configs: [], query: "", searching: false);

  HomeRawState copyWith({
    List<ConfigQueryRow>? configs,
    String? query,
    bool? searching,
  }) {
    return HomeRawState(
      configs: configs ?? this.configs,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

class HomeRawController extends Cubit<HomeRawState> {
  HomeRawController() : super(HomeRawState.initial()) {
    _asyncInit();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  final searchController = TextEditingController();
  var _allConfigs = <ConfigQueryRow>[];

  Future<void> _asyncInit() async {
    final db = AppDatabase();
    _configsSubscription = db.coreConfigDao.allRawRowsStream().listen((data) {
      _allConfigs = data;
      _emitFilteredConfigs();
    });
  }

  Future<void> ping(int subId) async {
    await PingService().pingRawConfigs(subId);
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    _allConfigs = await db.coreConfigDao.allRawRows;
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
    return super.close();
  }
}
