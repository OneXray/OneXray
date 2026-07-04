import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/service/ping/service.dart';

enum HomeNodeQueryType { homeNodes, outboundOnly }

class HomeNodeViewState {
  final List<ConfigQueryRow> configs;
  final String query;

  const HomeNodeViewState({required this.configs, required this.query});

  factory HomeNodeViewState.initial() =>
      const HomeNodeViewState(configs: [], query: "");

  HomeNodeViewState copyWith({List<ConfigQueryRow>? configs, String? query}) {
    return HomeNodeViewState(
      configs: configs ?? this.configs,
      query: query ?? this.query,
    );
  }
}

class HomeNodeController extends Cubit<HomeNodeViewState> {
  HomeNodeController({required this.queryType})
    : super(HomeNodeViewState.initial()) {
    _asyncInit();
  }

  final HomeNodeQueryType queryType;
  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  final searchController = TextEditingController();
  var _allConfigs = <ConfigQueryRow>[];

  Future<void> _asyncInit() async {
    final db = AppDatabase();
    _configsSubscription = _configRowsStream(db).listen((data) {
      _allConfigs = data;
      _emitFilteredConfigs();
    });
  }

  Stream<List<ConfigQueryRow>> _configRowsStream(AppDatabase db) {
    return switch (queryType) {
      HomeNodeQueryType.homeNodes => db.coreConfigDao.allHomeNodeRowsStream(),
      HomeNodeQueryType.outboundOnly =>
        db.coreConfigDao.allOutboundRowsStream(),
    };
  }

  Future<void> ping(int subId) async {
    switch (queryType) {
      case HomeNodeQueryType.homeNodes:
        await PingService().pingHomeNodeConfigs(subId);
        break;
      case HomeNodeQueryType.outboundOnly:
        await PingService().pingOutboundConfigs(subId);
        break;
    }
  }

  Future<void> cleanUnreachable(int subId) async {
    final db = AppDatabase();
    switch (queryType) {
      case HomeNodeQueryType.homeNodes:
        await db.coreConfigDao.deleteUnreachableHomeNodeRows(subId);
        break;
      case HomeNodeQueryType.outboundOnly:
        await db.coreConfigDao.deleteUnreachableOutboundRows(subId);
        break;
    }
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    _allConfigs = switch (queryType) {
      HomeNodeQueryType.homeNodes => await db.coreConfigDao.allHomeNodeRows,
      HomeNodeQueryType.outboundOnly => await db.coreConfigDao.allOutboundRows,
    };
    _emitFilteredConfigs();
  }

  void updateSearchQuery(String value) {
    _emitFilteredConfigs(query: value);
  }

  void clearSearch() {
    searchController.clear();
    _emitFilteredConfigs(query: "");
  }

  void _emitFilteredConfigs({String? query}) {
    final nextQuery = query ?? state.query;
    final configs = ConfigQueryFilter.filterRows(_allConfigs, nextQuery);
    emit(state.copyWith(configs: configs, query: nextQuery));
  }

  @override
  Future<void> close() {
    searchController.dispose();
    _configsSubscription?.cancel();
    return super.close();
  }
}
