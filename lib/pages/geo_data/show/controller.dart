import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/pages/geo_data/show/params.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/core/pigeon/constants.dart';

class GeoDatShowState {
  final List<XrayGeoListCodes> geoDatCodes;
  final String geoDatName;

  const GeoDatShowState({
    required this.geoDatCodes,
    required this.geoDatName,
  });

  factory GeoDatShowState.initial(GeoDatShowParams params) => GeoDatShowState(
        geoDatCodes: const [],
        geoDatName: params.name,
      );

  GeoDatShowState copyWith({
    List<XrayGeoListCodes>? geoDatCodes,
    String? geoDatName,
  }) {
    return GeoDatShowState(
      geoDatCodes: geoDatCodes ?? this.geoDatCodes,
      geoDatName: geoDatName ?? this.geoDatName,
    );
  }
}

class GeoDatShowController extends Cubit<GeoDatShowState> {
  final GeoDatShowParams params;
  GeoDatShowController(this.params) : super(GeoDatShowState.initial(params)) {
    _readGeoList();
  }

  final allGeoDatCodes = <XrayGeoListCodes>[];
  final searchController = TextEditingController();

  @override
  Future<void> close() {
    searchController.dispose();
    return super.close();
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
