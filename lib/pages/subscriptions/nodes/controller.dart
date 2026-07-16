import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/subscriptions/nodes/params.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';

class SubscriptionNodesPageState {
  final String subscriptionName;
  final List<CoreConfigData> configs;
  final String query;
  final bool searching;
  final bool missing;

  const SubscriptionNodesPageState({
    required this.subscriptionName,
    required this.configs,
    required this.query,
    required this.searching,
    required this.missing,
  });

  factory SubscriptionNodesPageState.initial() =>
      const SubscriptionNodesPageState(
        subscriptionName: "",
        configs: [],
        query: "",
        searching: false,
        missing: false,
      );

  SubscriptionNodesPageState copyWith({
    String? subscriptionName,
    List<CoreConfigData>? configs,
    String? query,
    bool? searching,
    bool? missing,
  }) {
    return SubscriptionNodesPageState(
      subscriptionName: subscriptionName ?? this.subscriptionName,
      configs: configs ?? this.configs,
      query: query ?? this.query,
      searching: searching ?? this.searching,
      missing: missing ?? this.missing,
    );
  }
}

class SubscriptionNodesController
    extends PageCubit<SubscriptionNodesPageState> {
  final SubscriptionNodesParams params;

  SubscriptionNodesController(this.params)
    : super(SubscriptionNodesPageState.initial()) {
    _init();
  }

  final searchController = TextEditingController();
  StreamSubscription<List<CoreConfigData>>? _configsSubscription;
  var _allConfigs = <CoreConfigData>[];

  Future<void> _init() async {
    final db = AppDatabase();
    final subscription = await db.subscriptionDao.searchRow(params.subId);
    if (!isPageActive) {
      return;
    }
    if (subscription == null) {
      emit(state.copyWith(missing: true));
      return;
    }
    emit(state.copyWith(subscriptionName: subscription.name));
    _configsSubscription = db.coreConfigDao
        .allOutboundRowsWithDataBySubIdStream(params.subId)
        .listen((data) {
          if (!isPageActive) {
            return;
          }
          _allConfigs = data;
          _emitFilteredConfigs();
        });
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
    final configs = ConfigQueryFilter.filterConfigs(_allConfigs, nextQuery);
    emit(
      state.copyWith(configs: configs, query: nextQuery, searching: searching),
    );
  }

  @override
  Future<void> disposePageResources() async {
    await _configsSubscription?.cancel();
    searchController.dispose();
  }
}
