import 'dart:async';
import 'package:onexray/pages/main/navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/core/geo_data/select/params.dart';
import 'package:onexray/pages/core/geo_data/show/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/system_state.dart';

class GeoDataListState {
  final List<GeoDataData> systemGeoDataList;
  final List<GeoDataData> geoDataList;
  final GeoDataListType type;
  final GeoDatCodesMode mode;
  final String query;
  final bool searching;

  const GeoDataListState({
    required this.systemGeoDataList,
    required this.geoDataList,
    required this.type,
    required this.mode,
    required this.query,
    required this.searching,
  });

  factory GeoDataListState.initial(GeoDataListParams params) =>
      GeoDataListState(
        systemGeoDataList: const [],
        geoDataList: const [],
        type: params.type,
        mode: params.mode,
        query: "",
        searching: false,
      );

  GeoDataListState copyWith({
    List<GeoDataData>? systemGeoDataList,
    List<GeoDataData>? geoDataList,
    GeoDataListType? type,
    GeoDatCodesMode? mode,
    String? query,
    bool? searching,
  }) {
    return GeoDataListState(
      systemGeoDataList: systemGeoDataList ?? this.systemGeoDataList,
      geoDataList: geoDataList ?? this.geoDataList,
      type: type ?? this.type,
      mode: mode ?? this.mode,
      query: query ?? this.query,
      searching: searching ?? this.searching,
    );
  }
}

class GeoDataListController extends Cubit<GeoDataListState> {
  final GeoDataListParams params;
  GeoDataListController(this.params) : super(GeoDataListState.initial(params)) {
    _asyncInit();
  }

  final selection = <String, Set<String>>{};
  StreamSubscription<List<GeoDataData>>? _geoDataSubscription;
  final searchController = TextEditingController();
  var _allGeoDataList = <GeoDataData>[];

  @override
  Future<void> close() {
    searchController.dispose();
    _geoDataSubscription?.cancel();
    return super.close();
  }

  Future<void> _asyncInit() async {
    await _readSystemGeoData();
    _queryGeoDataList();
  }

  Future<void> _readSystemGeoData() async {
    var systemGeoDat = <GeoDataData>[];
    switch (state.type) {
      case GeoDataListType.full:
        systemGeoDat = await SystemGeoDatState.system;
        break;
      case GeoDataListType.domain:
        systemGeoDat = await SystemGeoDatState.geoSite;
        break;
      case GeoDataListType.ip:
        systemGeoDat = await SystemGeoDatState.geoIp;
        break;
    }
    emit(state.copyWith(systemGeoDataList: systemGeoDat));
  }

  void _queryGeoDataList() {
    final db = AppDatabase();
    Stream<List<GeoDataData>> stream;
    switch (state.type) {
      case GeoDataListType.full:
        stream = db.geoDataDao.allRowsStream;
        break;
      case GeoDataListType.domain:
        stream = db.geoDataDao.allDomainRowsStream;
        break;
      case GeoDataListType.ip:
        stream = db.geoDataDao.allIpRowsStream;
        break;
    }
    _geoDataSubscription?.cancel();
    _geoDataSubscription = stream.listen((data) {
      _allGeoDataList = data;
      _emitFilteredGeoDataList();
    });
  }

  void updateSearchQuery(String value) {
    _emitFilteredGeoDataList(query: value);
  }

  void toggleSearch() {
    if (state.searching) {
      searchController.clear();
      _emitFilteredGeoDataList(query: "", searching: false);
    } else {
      emit(state.copyWith(searching: true));
    }
  }

  void _emitFilteredGeoDataList({String? query, bool? searching}) {
    final nextQuery = query ?? state.query;
    emit(
      state.copyWith(
        geoDataList: _filterRows(_allGeoDataList, nextQuery),
        query: nextQuery,
        searching: searching,
      ),
    );
  }

  List<GeoDataData> filterSystemGeoDataList() {
    return _filterRows(state.systemGeoDataList, state.query);
  }

  List<GeoDataData> _filterRows(List<GeoDataData> rows, String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) {
      return rows;
    }
    return rows.where((row) => _matches(row, keyword)).toList();
  }

  bool _matches(GeoDataData row, String keyword) {
    return row.name.toLowerCase().contains(keyword) ||
        row.type.toLowerCase().contains(keyword) ||
        row.url.toLowerCase().contains(keyword) ||
        "${row.categoryCount}".contains(keyword) ||
        "${row.ruleCount}".contains(keyword);
  }

  void addGeoData(BuildContext context) {
    context.pushScoped(
      AppSecondaryDestination.geoDatAdd,
      extra: DBConstants.defaultId,
    );
  }

  Future<void> gotoGeoData(BuildContext context, GeoDataData geoData) async {
    var selections = <String>{};
    if (selection[geoData.name] != null) {
      selections = selection[geoData.name]!;
    }

    switch (state.mode) {
      case GeoDatCodesMode.show:
        final params = GeoDatShowParams(geoData.name);
        context.pushScoped(AppSecondaryDestination.geoDatShow, extra: params);
        break;
      case GeoDatCodesMode.select:
        final params = GeoDatSelectParams(geoData.name, selections);
        final selectedList = await context.pushScoped<Set<String>>(
          AppSecondaryDestination.geoDatSelect,
          extra: params,
        );
        if (selectedList != null) {
          if (selectedList.isEmpty) {
            selection.remove(geoData.name);
          } else {
            selection[geoData.name] = selectedList;
          }
        }
        break;
    }
  }

  Future<void> refreshSystemGeoDat(BuildContext context) async {
    final eventBus = AppEventBus.instance;
    if (eventBus.state.downloading) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.runningAndWait,
        );
      }
      return;
    }
    await GeoDataService().refreshSystemGeoDat(state.systemGeoDataList);
    await _readSystemGeoData();
  }

  Future<void> moreAction(
    BuildContext context,
    GeoDataData geoDat,
    String menuId,
  ) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    switch (id) {
      case IconMenuId.refresh:
        await _updateGeoDat(context, geoDat);
        break;
      case IconMenuId.delete:
        await GeoDataService().deleteGeoDat(geoDat);
        break;
      default:
        break;
    }
  }

  Future<void> _updateGeoDat(BuildContext context, GeoDataData geoDat) async {
    final eventBus = AppEventBus.instance;
    if (eventBus.state.downloading) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.runningAndWait,
        );
      }
      return;
    }
    await GeoDataService().updateGeoDat(geoDat);
  }

  void save(BuildContext context) {
    final selections = <String>{};
    selection.forEach((key, values) {
      if (key == SystemGeoDatName.geoSite.name ||
          key == SystemGeoDatName.geoIp.name) {
        for (final value in values) {
          selections.add("$key:$value");
        }
      } else {
        for (final value in values) {
          selections.add("ext:$key.dat:$value");
        }
      }
    });
    context.pop(selections);
  }
}
