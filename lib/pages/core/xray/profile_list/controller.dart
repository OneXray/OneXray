import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/widget/config_query_filter.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class XrayProfileListItem {
  final CoreConfigData config;
  final bool builtIn;

  const XrayProfileListItem({required this.config, required this.builtIn});
}

class XrayProfileListPageState {
  final int xrayProfileId;
  final List<XrayProfileListItem> profiles;
  final String query;
  final bool searching;

  const XrayProfileListPageState({
    required this.xrayProfileId,
    required this.profiles,
    required this.query,
    required this.searching,
  });

  factory XrayProfileListPageState.initial() => const XrayProfileListPageState(
    xrayProfileId: XrayProfileSimple.simpleId,
    profiles: [],
    query: "",
    searching: false,
  );

  XrayProfileListPageState copyWith({
    int? xrayProfileId,
    List<XrayProfileListItem>? profiles,
    String? query,
    bool? searching,
  }) {
    return XrayProfileListPageState(
      xrayProfileId: xrayProfileId ?? this.xrayProfileId,
      profiles: profiles ?? this.profiles,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

class XrayProfileListController extends PageCubit<XrayProfileListPageState> {
  XrayProfileListController() : super(XrayProfileListPageState.initial()) {
    _readData();
  }

  StreamSubscription<List<ConfigQueryRow>>? _configsSubscription;
  final searchController = TextEditingController();
  XrayProfileListItem? _simpleProfile;
  var _customProfiles = <XrayProfileListItem>[];

  List<XrayProfileListItem> get _allProfiles => [
    ?_simpleProfile,
    ..._customProfiles,
  ];

  Future<void> _readData() async {
    await _readXrayProfileId();
    if (!isPageActive) {
      return;
    }
    _initSimpleProfile();
    _queryXrayProfileList();
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
      if (!isPageActive) {
        return;
      }
      _updateCustomProfiles(data);
      _emitFilteredProfiles();
    });
  }

  void _initSimpleProfile() {
    final config = CoreConfigData(
      id: XrayProfileSimple.simpleId,
      name: appLocalizationsNoContext().xrayProfileListPageSimple,
      type: CoreConfigType.profile.name,
      tags: "",
      delay: PingDelayConstants.unknown,
      subId: XrayProfileSimple.simpleId,
    );
    _simpleProfile = XrayProfileListItem(config: config, builtIn: true);
    _emitFilteredProfiles();
  }

  void _updateCustomProfiles(List<ConfigQueryRow> rows) {
    _customProfiles = rows
        .whereType<ConfigItem>()
        .map((item) => XrayProfileListItem(config: item.config, builtIn: false))
        .toList();
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
    _updateCustomProfiles(await db.coreConfigDao.allSettingRows);
    _emitFilteredProfiles();
  }

  void updateSearchQuery(String value) {
    _emitFilteredProfiles(query: value);
  }

  void toggleSearch() {
    if (state.searching) {
      searchController.clear();
      _emitFilteredProfiles(query: "", searching: false);
    } else {
      emit(state.copyWith(searching: true));
    }
  }

  void _emitFilteredProfiles({String? query, bool? searching}) {
    final nextQuery = query ?? state.query;
    final profiles = _allProfiles;
    final filteredIds = ConfigQueryFilter.filterConfigs(
      profiles.map((item) => item.config).toList(),
      nextQuery,
    ).map((config) => config.id).toSet();
    emit(
      state.copyWith(
        profiles: profiles
            .where((item) => filteredIds.contains(item.config.id))
            .toList(),
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
        _editXrayProfile(context, config.id);
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

  void _editXrayProfile(BuildContext context, int id) {
    final destination = editorDestination(id);
    if (destination == AppSecondaryDestination.xrayProfileSimple) {
      context.pushScoped(destination);
      return;
    }
    _gotoXrayProfileUI(context, id);
  }

  static AppSecondaryDestination editorDestination(int id) {
    return id == XrayProfileSimple.simpleId
        ? AppSecondaryDestination.xrayProfileSimple
        : AppSecondaryDestination.xrayProfileUI;
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
  Future<void> disposePageResources() async {
    await _configsSubscription?.cancel();
    searchController.dispose();
  }
}
