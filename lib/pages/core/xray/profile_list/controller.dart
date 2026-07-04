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
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class XrayProfileListPageState {
  final int xrayProfileId;
  final List<ConfigQueryRow> simpleConfigs;
  final List<ConfigQueryRow> configs;
  final String query;
  final bool searching;

  const XrayProfileListPageState({
    required this.xrayProfileId,
    required this.simpleConfigs,
    required this.configs,
    required this.query,
    required this.searching,
  });

  factory XrayProfileListPageState.initial() => const XrayProfileListPageState(
    xrayProfileId: XrayProfileSimple.simpleId,
    simpleConfigs: [],
    configs: [],
    query: "",
    searching: false,
  );

  XrayProfileListPageState copyWith({
    int? xrayProfileId,
    List<ConfigQueryRow>? simpleConfigs,
    List<ConfigQueryRow>? configs,
    String? query,
    bool? searching,
  }) {
    return XrayProfileListPageState(
      xrayProfileId: xrayProfileId ?? this.xrayProfileId,
      simpleConfigs: simpleConfigs ?? this.simpleConfigs,
      configs: configs ?? this.configs,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

class XrayProfileListController extends Cubit<XrayProfileListPageState> {
  XrayProfileListController() : super(XrayProfileListPageState.initial()) {
    _readData();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  final searchController = TextEditingController();
  var _allSimpleConfigs = <ConfigQueryRow>[];
  var _allConfigs = <ConfigQueryRow>[];

  Future<void> _readData() async {
    await _readXrayProfileId();
    _queryXrayProfileList();
    _initSimpleConfigs();
  }

  Future<void> _readXrayProfileId() async {
    final id = await PreferencesKey().readXrayProfileId();
    emit(state.copyWith(xrayProfileId: id));
  }

  void _queryXrayProfileList() {
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
      id: XrayProfileSimple.simpleId,
      name: appLocalizationsNoContext().xrayProfileListPageSimple,
      url: "",
      timestamp: DateTime.now(),
      count: 1,
      expanded: true,
    );
    final simpleSub = SubscriptionItem(sub, ConfigQueryRowType.subscription);

    final config = CoreConfigData(
      id: XrayProfileSimple.simpleId,
      name: appLocalizationsNoContext().xrayProfileListPageSimple,
      type: CoreConfigType.profile.name,
      tags: "",
      delay: PingDelayConstants.unknown,
      subId: XrayProfileSimple.simpleId,
    );
    final simpleConfig = ConfigItem(config, ConfigQueryRowType.config);

    _allSimpleConfigs = [simpleSub, simpleConfig];
    _emitFilteredConfigs();
  }

  void updateXrayProfileId(BuildContext context, int? id) {
    if (id == null || state.xrayProfileId == id) {
      return;
    }
    emit(state.copyWith(xrayProfileId: id));
  }

  void addXrayProfile(BuildContext context) {
    _gotoXrayProfileUI(context, DBConstants.defaultId);
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
    IconMenuId menuId,
  ) async {
    final db = AppDatabase();
    switch (menuId) {
      case IconMenuId.edit:
        _gotoXrayProfileUI(context, config.id);
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

  void _gotoXrayProfileUI(BuildContext context, int id) {
    final params = XrayProfileUIParams(id);
    context.pushScoped(AppSecondaryDestination.xrayProfileUI, extra: params);
  }

  Future<void> _deleteSetting(CoreConfigData setting) async {
    if (setting.id == XrayProfileSimple.simpleId ||
        setting.id == state.xrayProfileId) {
      ToastService().showToast(
        appLocalizationsNoContext().xrayProfileListPageDeleteSelectedBlocked,
      );
      return;
    }
    final db = AppDatabase();
    await db.coreConfigDao.deleteRow(setting);
  }

  Future<void> _updateSettingId() async {
    final settingId = state.xrayProfileId == DBConstants.defaultId
        ? XrayProfileSimple.simpleId
        : state.xrayProfileId;
    await PreferencesKey().saveXrayProfileId(settingId);
    AppEventBus.instance.updateXrayProfileId(settingId);
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
