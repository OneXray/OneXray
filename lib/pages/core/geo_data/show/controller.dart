import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/pages/core/geo_data/show/params.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/core/pigeon/constants.dart';

class GeoDatShowPageState {
  final List<XrayGeoListCodes> geoDatCodes;
  final String geoDatName;

  const GeoDatShowPageState({
    required this.geoDatCodes,
    required this.geoDatName,
  });

  factory GeoDatShowPageState.initial(GeoDatShowParams params) =>
      GeoDatShowPageState(geoDatCodes: const [], geoDatName: params.name);

  GeoDatShowPageState copyWith({
    List<XrayGeoListCodes>? geoDatCodes,
    String? geoDatName,
  }) {
    return GeoDatShowPageState(
      geoDatCodes: geoDatCodes ?? this.geoDatCodes,
      geoDatName: geoDatName ?? this.geoDatName,
    );
  }
}

class GeoDatShowController extends PageCubit<GeoDatShowPageState> {
  final GeoDatShowParams params;
  GeoDatShowController(this.params)
    : super(GeoDatShowPageState.initial(params)) {
    _readGeoList();
  }

  final allGeoDatCodes = <XrayGeoListCodes>[];
  final searchController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    searchController.dispose();
  }

  Future<void> _readGeoList() async {
    final geoList = await GeoDataService().readGeoList(
      VpnConstants.datDir,
      state.geoDatName,
    );
    if (EmptyTool.checkList(geoList.codes)) {
      allGeoDatCodes.clear();
      allGeoDatCodes.addAll(geoList.codes!);
      emit(state.copyWith(geoDatCodes: List.from(geoList.codes!)));
    }
  }

  void keywordChanged(String value) {
    if (value.isNotEmpty) {
      final filterCodes = allGeoDatCodes.where((e) {
        if (e.code != null) {
          return e.code!.toLowerCase().contains(value.toLowerCase());
        }
        return false;
      }).toList();
      emit(state.copyWith(geoDatCodes: filterCodes));
    } else {
      emit(state.copyWith(geoDatCodes: List.from(allGeoDatCodes)));
    }
  }
}
