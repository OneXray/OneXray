import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/geo_data/select/params.dart';
import 'package:onexray/pages/geo_data/show/params.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/main/url.dart';
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

  const GeoDataListState({
    required this.systemGeoDataList,
    required this.geoDataList,
    required this.type,
    required this.mode,
  });

  factory GeoDataListState.initial(GeoDataListParams params) =>
      GeoDataListState(
        systemGeoDataList: const [],
        geoDataList: const [],
        type: params.type,
        mode: params.mode,
      );

  GeoDataListState copyWith({
    List<GeoDataData>? systemGeoDataList,
    List<GeoDataData>? geoDataList,
    GeoDataListType? type,
    GeoDatCodesMode? mode,
  }) {
    return GeoDataListState(
      systemGeoDataList: systemGeoDataList ?? this.systemGeoDataList,
      geoDataList: geoDataList ?? this.geoDataList,
      type: type ?? this.type,
      mode: mode ?? this.mode,
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

  @override
  Future<void> close() {
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
      emit(state.copyWith(geoDataList: data));
    });
  }

  void addGeoData(BuildContext context) {
    context.push(RouterPath.geoDatAdd, extra: DBConstants.defaultId);
  }

  Future<void> gotoGeoData(BuildContext context, GeoDataData geoData) async {
    var selections = <String>{};
    if (selection[geoData.name] != null) {
      selections = selection[geoData.name]!;
    }

    switch (state.mode) {
      case GeoDatCodesMode.show:
        final params = GeoDatShowParams(geoData.name);
        context.push(RouterPath.geoDatShow, extra: params);
        break;
      case GeoDatCodesMode.select:
        final params = GeoDatSelectParams(geoData.name, selections);
        final selectedList = await context.push<Set<String>>(
          RouterPath.geoDatSelect,
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
      case IconMenuId.share:
        _shareGeoDat(context, geoDat);
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

  void _shareGeoDat(BuildContext context, GeoDataData geoDat) async {
    final params = SharePageParams(ShareType.geoDat, geoDat.id);
    context.push(RouterPath.share, extra: params);
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
