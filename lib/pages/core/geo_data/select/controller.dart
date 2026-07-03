import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/pages/core/geo_data/select/params.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/core/pigeon/constants.dart';

class GeoDatSelectPageState {
  final List<XrayGeoListCodes> geoDatCodes;
  final String geoDatName;
  final Set<String> selections;

  const GeoDatSelectPageState({
    required this.geoDatCodes,
    required this.geoDatName,
    required this.selections,
  });

  factory GeoDatSelectPageState.initial(GeoDatSelectParams params) =>
      GeoDatSelectPageState(
        geoDatCodes: const [],
        geoDatName: params.name,
        selections: const {},
      );

  GeoDatSelectPageState copyWith({
    List<XrayGeoListCodes>? geoDatCodes,
    String? geoDatName,
    Set<String>? selections,
  }) {
    return GeoDatSelectPageState(
      geoDatCodes: geoDatCodes ?? this.geoDatCodes,
      geoDatName: geoDatName ?? this.geoDatName,
      selections: selections ?? this.selections,
    );
  }
}

class GeoDatSelectController extends Cubit<GeoDatSelectPageState> {
  final GeoDatSelectParams params;
  GeoDatSelectController(this.params)
    : super(GeoDatSelectPageState.initial(params)) {
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
    if (isClosed) {
      return;
    }
    if (EmptyTool.checkList(geoList.codes)) {
      final newSelections = <String>{};
      for (final selection in params.selections) {
        for (final code in geoList.codes!) {
          if (code.code == selection) {
            newSelections.add(selection);
          }
        }
      }

      allGeoDatCodes.clear();
      allGeoDatCodes.addAll(geoList.codes!);
      emit(
        state.copyWith(
          geoDatCodes: List.from(geoList.codes!),
          selections: newSelections,
        ),
      );
    }
  }

  void updateSelections(bool? checked, String? code) {
    if (checked != null && code != null) {
      final newSelections = Set<String>.from(state.selections);
      if (checked) {
        newSelections.add(code);
      } else {
        newSelections.remove(code);
      }
      emit(state.copyWith(selections: newSelections));
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

  void save(BuildContext context) {
    context.pop(state.selections);
  }
}
