import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/tun/network_interface/params.dart';
import 'package:onexray/service/tun_settings/interface.dart';

class NetworkInterfacePageState {
  final String currentInterface;
  final List<NetworkInterface> interfaceList;

  const NetworkInterfacePageState({
    this.currentInterface = "",
    this.interfaceList = const [],
  });

  NetworkInterfacePageState copyWith({
    String? currentInterface,
    List<NetworkInterface>? interfaceList,
  }) {
    return NetworkInterfacePageState(
      currentInterface: currentInterface ?? this.currentInterface,
      interfaceList: interfaceList ?? this.interfaceList,
    );
  }
}

class NetworkInterfaceController extends Cubit<NetworkInterfacePageState> {
  final NetworkInterfaceParams params;

  NetworkInterfaceController(this.params)
    : super(const NetworkInterfacePageState()) {
    _initParams();
    _queryInterfaceList();
  }

  void _initParams() {
    emit(state.copyWith(currentInterface: params.currentInterface));
  }

  Future<void> _queryInterfaceList() async {
    final interfaces = await queryInterfaceList();
    emit(state.copyWith(interfaceList: interfaces));
  }

  void updateInterface(String? value) {
    if (value != null) {
      emit(state.copyWith(currentInterface: value));
    }
  }

  Future<void> save(BuildContext context) async {
    if (context.mounted) {
      context.pop(state.currentInterface);
    }
  }
}
