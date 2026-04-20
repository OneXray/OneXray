import 'dart:async';

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
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class XraySettingListState {
  final int xraySettingId;
  final List<ConfigQueryRow> simpleConfigs;
  final List<ConfigQueryRow> configs;

  const XraySettingListState({
    required this.xraySettingId,
    required this.simpleConfigs,
    required this.configs,
  });

  factory XraySettingListState.initial() => const XraySettingListState(
        xraySettingId: DBConstants.defaultId,
        simpleConfigs: [],
        configs: [],
      );

  XraySettingListState copyWith({
    int? xraySettingId,
    List<ConfigQueryRow>? simpleConfigs,
    List<ConfigQueryRow>? configs,
  }) {
    return XraySettingListState(
      xraySettingId: xraySettingId ?? this.xraySettingId,
      simpleConfigs: simpleConfigs ?? this.simpleConfigs,
      configs: configs ?? this.configs,
    );
  }
}

class XraySettingListController extends Cubit<XraySettingListState> {
  XraySettingListController() : super(XraySettingListState.initial()) {
    _readData();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;

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
    _configsSubscription = db.coreConfigDao.allSettingRowsStream().listen(
      (data) => emit(state.copyWith(configs: data)),
    );
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

    emit(state.copyWith(simpleConfigs: [simpleSub, simpleConfig]));
  }

  void updateXraySettingId(BuildContext context, int? id) {
    if (id == null || state.xraySettingId == id) {
      emit(state.copyWith(xraySettingId: DBConstants.defaultId));
    } else {
      emit(state.copyWith(xraySettingId: id));
    }
  }

  void addXraySetting(BuildContext context) {
    _gotoXraySettingUI(context, DBConstants.defaultId);
  }

  Future<void> refreshData() async {
    final db = AppDatabase();
    final newList = await db.coreConfigDao.allSettingRows;
    emit(state.copyWith(configs: newList));
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
          context.push(RouterPath.share, extra: params);
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
    context.push(RouterPath.xraySettingUI, extra: params);
  }

  Future<void> _deleteSetting(CoreConfigData setting) async {
    final db = AppDatabase();
    await db.coreConfigDao.deleteRow(setting);
    if (setting.id == state.xraySettingId) {
      emit(state.copyWith(xraySettingId: DBConstants.defaultId));
      await _updateSettingId();
    }
  }

  Future<void> _updateSettingId() async {
    final settingId = state.xraySettingId;
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
    _configsSubscription?.cancel();
    return super.close();
  }
}
