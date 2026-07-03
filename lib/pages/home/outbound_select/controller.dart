import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';

class OutboundSelectPageState {
  final List<CoreConfigData> configs;
  final String query;

  const OutboundSelectPageState({required this.configs, required this.query});

  factory OutboundSelectPageState.initial() =>
      const OutboundSelectPageState(configs: [], query: "");

  OutboundSelectPageState copyWith({
    List<CoreConfigData>? configs,
    String? query,
  }) {
    return OutboundSelectPageState(
      configs: configs ?? this.configs,
      query: query ?? this.query,
    );
  }
}

class OutboundSelectController extends Cubit<OutboundSelectPageState> {
  OutboundSelectController() : super(OutboundSelectPageState.initial()) {
    _queryConfigs();
  }

  final searchController = TextEditingController();
  var _allConfigs = <CoreConfigData>[];

  Future<void> _queryConfigs() async {
    final db = AppDatabase();
    _allConfigs = await db.coreConfigDao.allOutboundRowsWithData;
    _emitFilteredConfigs();
  }

  void updateSearchQuery(String value) {
    _emitFilteredConfigs(query: value);
  }

  void _emitFilteredConfigs({String? query}) {
    final nextQuery = query ?? state.query;
    final configs = ConfigQueryFilter.filterConfigs(_allConfigs, nextQuery);
    emit(state.copyWith(configs: configs, query: nextQuery));
  }

  void select(BuildContext context, CoreConfigData config) {
    context.pop<CoreConfigData>(config);
  }

  @override
  Future<void> close() {
    searchController.dispose();
    return super.close();
  }
}
