import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/ping/service.dart';

class HomeRawState {
  final List<ConfigQueryRow> configs;

  const HomeRawState({required this.configs});

  factory HomeRawState.initial() => const HomeRawState(configs: []);

  HomeRawState copyWith({List<ConfigQueryRow>? configs}) {
    return HomeRawState(configs: configs ?? this.configs);
  }
}

class HomeRawController extends Cubit<HomeRawState> {
  HomeRawController() : super(HomeRawState.initial()) {
    _asyncInit();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;

  Future<void> _asyncInit() async {
    final db = AppDatabase();
    _configsSubscription = db.coreConfigDao.allRawRowsStream().listen(
      (data) => emit(state.copyWith(configs: data)),
    );
  }

  Future<void> ping(int subId) async {
    await PingService().pingRawConfigs(subId);
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    final newList = await db.coreConfigDao.allRawRows;
    emit(state.copyWith(configs: newList));
  }

  @override
  Future<void> close() {
    _configsSubscription?.cancel();
    return super.close();
  }
}
