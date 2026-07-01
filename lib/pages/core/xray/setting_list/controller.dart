import 'dart:async';
import 'package:onexray/pages/main/navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/core/xray/setting/ui/params.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class XraySettingListState {
  final int xraySettingId;
  final List<ConfigQueryRow> simpleConfigs;
  final List<ConfigQueryRow> configs;
  final String query;
  final bool searching;

  const XraySettingListState({
    required this.xraySettingId,
    required this.simpleConfigs,
    required this.configs,
    required this.query,
    required this.searching,
  });

  factory XraySettingListState.initial() => const XraySettingListState(
    xraySettingId: XraySettingSimple.simpleId,
    simpleConfigs: [],
    configs: [],
    query: "",
    searching: false,
  );

  XraySettingListState copyWith({
    int? xraySettingId,
    List<ConfigQueryRow>? simpleConfigs,
    List<ConfigQueryRow>? configs,
    String? query,
    bool? searching,
  }) {
    return XraySettingListState(
      xraySettingId: xraySettingId ?? this.xraySettingId,
      simpleConfigs: simpleConfigs ?? this.simpleConfigs,
      configs: configs ?? this.configs,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

class XraySettingListController extends Cubit<XraySettingListState> {
  XraySettingListController() : super(XraySettingListState.initial()) {
    _readData();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  final searchController = TextEditingController();
  var _allSimpleConfigs = <ConfigQueryRow>[];
  var _allConfigs = <ConfigQueryRow>[];

  Future<void> _readData() async {
    await _readXraySettingId();
    _queryXraySettingList();
    _initSimpleConfigs();
  }

  Future<void> _readXraySettingId() async {
    final id = await PreferencesKey().readXraySettingId();
    emit(state.copyWith(xraySettingId: id));
  }

  void _queryXraySettingList() {
    final db = AppDatabase();
    _configsSubscription = db.coreConfigDao.allSettingRowsStream().listen((
      data,
    ) {
      _allConfigs = data;
      _emitFilteredConfigs();
    });
  }

  void _initSimpleConfigs() {
    final sub = SubscriptionData(
      id: XraySettingSimple.simpleId,
      name: appLocalizationsNoContext().xraySettingListPageSimple,
      url: "",
      timestamp: DateTime.now(),
      count: 1,
      expanded: true,
    );
    final simpleSub = SubscriptionItem(sub, ConfigQueryRowType.subscription);

    final config = CoreConfigData(
      id: XraySettingSimple.simpleId,
      name: appLocalizationsNoContext().xraySettingListPageSimple,
      type: CoreConfigType.setting.name,
      tags: "",
      delay: PingDelayConstants.unknown,
      subId: XraySettingSimple.simpleId,
    );
    final simpleConfig = ConfigItem(config, ConfigQueryRowType.config);

    _allSimpleConfigs = [simpleSub, simpleConfig];
    _emitFilteredConfigs();
  }

  void updateXraySettingId(BuildContext context, int? id) {
    if (id == null || state.xraySettingId == id) {
      return;
    }
    emit(state.copyWith(xraySettingId: id));
  }

  void addXraySetting(BuildContext context) {
    _gotoXraySettingUI(context, DBConstants.defaultId);
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    _allConfigs = await db.coreConfigDao.allSettingRows;
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
    emit(
      state.copyWith(
        simpleConfigs: ConfigQueryFilter.filterRows(
          _allSimpleConfigs,
          nextQuery,
        ),
        configs: ConfigQueryFilter.filterRows(_allConfigs, nextQuery),
        query: nextQuery,
        searching: searching,
      ),
    );
  }

  Future<void> moreAction(
    BuildContext context,
    CoreConfigData config,
    String menuId,
  ) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    final db = AppDatabase();
    switch (id) {
      case IconMenuId.edit:
        _gotoXraySettingUI(context, config.id);
        break;
      case IconMenuId.share:
        if (context.mounted) {
          final params = SharePageParams(ShareType.config, config.id);
          context.pushScoped(AppSecondaryDestination.share, extra: params);
        }
        break;
      case IconMenuId.copy:
        await db.coreConfigDao.copyRow(config.id);
        break;
      case IconMenuId.delete:
        await _deleteSetting(config);
        break;
      default:
        break;
    }
  }

  void _gotoXraySettingUI(BuildContext context, int id) {
    final params = XraySettingUIParams(id);
    context.pushScoped(AppSecondaryDestination.xraySettingUI, extra: params);
  }

  Future<void> _deleteSetting(CoreConfigData setting) async {
    if (setting.id == XraySettingSimple.simpleId ||
        setting.id == state.xraySettingId) {
      ToastService().showToast(
        appLocalizationsNoContext().xraySettingListPageDeleteSelectedBlocked,
      );
      return;
    }
    final db = AppDatabase();
    await db.coreConfigDao.deleteRow(setting);
  }

  Future<void> _updateSettingId() async {
    final settingId = state.xraySettingId == DBConstants.defaultId
        ? XraySettingSimple.simpleId
        : state.xraySettingId;
    await PreferencesKey().saveXraySettingId(settingId);
    AppEventBus.instance.updateXraySettingId(settingId);
  }

  Future<void> save(BuildContext context) async {
    await _updateSettingId();
    if (context.mounted) {
      context.pop();
    }
  }

  @override
  Future<void> close() {
    searchController.dispose();
    _configsSubscription?.cancel();
    return super.close();
  }
}
